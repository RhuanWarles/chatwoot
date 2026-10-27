# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Channel::WebWidget do
  context 'when
  web widget channel' do
    let!(:channel_widget) { create(:channel_widget) }

    it 'pre chat options' do
      expect(channel_widget.pre_chat_form_options['pre_chat_message']).to eq 'Share your queries or comments here.'
      expect(channel_widget.pre_chat_form_options['pre_chat_fields'].length).to eq 3
    end
  end

  describe 'footer branding' do
    let(:channel_widget) { create(:channel_widget) }
    let(:logo_path) { Rails.root.join('spec/assets/avatar.png') }

    def attach_logo(path = logo_path, content_type = 'image/png')
      channel_widget.branding_logo.attach(io: File.open(path), filename: File.basename(path), content_type: content_type)
    end

    it 'is empty by default' do
      expect(channel_widget.branding_text).to be_nil
      expect(channel_widget.branding_url).to be_nil
      expect(channel_widget.branding_logo_url).to eq('')
    end

    it 'turns blank values into nil' do
      channel_widget.update!(branding_text: '  ', branding_url: ' ')

      expect(channel_widget.reload.branding_text).to be_nil
      expect(channel_widget.branding_url).to be_nil
    end

    it 'limits the text to 100 characters' do
      channel_widget.branding_text = 'a' * 101

      expect(channel_widget).not_to be_valid
      expect(channel_widget.errors[:branding_text]).to be_present
    end

    it 'accepts only http and https links' do
      ['https://acme.com', 'http://acme.com/path?a=1'].each do |url|
        channel_widget.branding_url = url
        expect(channel_widget).to be_valid
      end

      ['javascript:alert(1)', 'ftp://acme.com', 'acme.com', 'https://'].each do |url|
        channel_widget.branding_url = url
        expect(channel_widget).not_to be_valid
        expect(channel_widget.errors[:branding_url]).to be_present
      end
    end

    it 'attaches a supported image and exposes its url' do
      attach_logo

      expect(channel_widget).to be_valid
      expect(channel_widget.branding_logo_url).to include('active_storage')
    end

    it 'rejects files that are not images' do
      attach_logo(Rails.root.join('spec/assets/sample.pdf'), 'application/pdf')

      expect(channel_widget).not_to be_valid
      expect(channel_widget.errors[:branding_logo]).to include('filetype not supported')
    end

    it 'rejects images over the size limit' do
      stub_const('Channel::WebWidget::BRANDING_LOGO_MAX_SIZE', 1.byte)
      attach_logo

      expect(channel_widget).not_to be_valid
      expect(channel_widget.errors[:branding_logo]).to include('is too big')
    end

    it 'removes the logo when remove_branding_logo is set' do
      attach_logo
      expect(channel_widget.reload.branding_logo).to be_attached

      channel_widget.update!(remove_branding_logo: true)

      expect(channel_widget.reload.branding_logo).not_to be_attached
      expect(channel_widget.branding_logo_url).to eq('')
    end
  end
end
