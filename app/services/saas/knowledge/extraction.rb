require 'tempfile'
require 'timeout'
require 'English'

class Saas::Knowledge::Extraction
  def self.call(document)
    return [{ content: document.content.to_s }] if document.source_type == 'manual'

    document.file.open do |file|
      return extract_pdf(file) if document.source_type == 'pdf'

      [{ content: File.read(file.path, encoding: 'UTF-8') }]
    end
  end

  def self.extract_pdf(file)
    Tempfile.create(['knowledge', '.txt']) do |output|
      run_pdf_command('pdfinfo', file.path, out: output.path)
      pages = File.read(output.path)[/^Pages:\s+(\d+)/, 1].to_i
      raise CustomExceptions::SaasError, 'too_many_pages' if pages > 200

      run_pdf_command('pdftotext', '-enc', 'UTF-8', file.path, output.path)
      raise CustomExceptions::SaasError, 'text_too_large' if output.size > Saas::KnowledgeDocument::MAX_TEXT_LENGTH * 4

      File.read(output.path, encoding: 'UTF-8').split("\f").each_with_index.map { |content, index| { content: content, page: index + 1 } }
    end
  end

  def self.run_pdf_command(*, **)
    limit = Saas::KnowledgeDocument::MAX_TEXT_LENGTH * 4
    pid = Process.spawn(*, **, err: File::NULL, rlimit_fsize: limit)
    Timeout.timeout(30) { Process.wait(pid) }
    raise CustomExceptions::SaasError, 'extraction_failed' unless $CHILD_STATUS.success?
  rescue Timeout::Error
    Process.kill('KILL', pid)
    Process.wait(pid)
    raise CustomExceptions::SaasError, 'extraction_timeout'
  end
  private_class_method :run_pdf_command, :extract_pdf
end
