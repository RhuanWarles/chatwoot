require 'rails_helper'

RSpec.describe AiAgentsConfiguration do
  describe '.configure' do
    it 'does not query installation configs before its table exists' do
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).with('installation_configs').and_return(false)
      expect(InstallationConfig).not_to receive(:find_by)
      expect(Agents).not_to receive(:configure)

      described_class.configure
    end

    it 'skips configuration when the database does not exist yet' do
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).with('installation_configs')
        .and_raise(ActiveRecord::NoDatabaseError, 'database does not exist')
      expect(InstallationConfig).not_to receive(:find_by)
      expect(Agents).not_to receive(:configure)

      described_class.configure
    end

    it 'configures the SDK when installation configs are available' do
      sdk_config = double('AgentsConfig')
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).with('installation_configs').and_return(true)
      allow(InstallationConfig).to receive(:find_by).with(name: 'CAPTAIN_OPEN_AI_API_KEY')
        .and_return(instance_double(InstallationConfig, value: 'test-key'))
      allow(InstallationConfig).to receive(:find_by).with(name: 'CAPTAIN_OPEN_AI_MODEL')
        .and_return(instance_double(InstallationConfig, value: 'test-model'))
      allow(InstallationConfig).to receive(:find_by).with(name: 'CAPTAIN_OPEN_AI_ENDPOINT')
        .and_return(instance_double(InstallationConfig, value: 'https://llm.example'))
      allow(Agents).to receive(:configure) { |&block| block.call(sdk_config) }

      allow(sdk_config).to receive(:openai_api_key=)
      allow(sdk_config).to receive(:openai_api_base=)
      allow(sdk_config).to receive(:default_model=)
      allow(sdk_config).to receive(:debug=)

      described_class.configure

      expect(sdk_config).to have_received(:openai_api_key=).with('test-key')
      expect(sdk_config).to have_received(:openai_api_base=).with('https://llm.example/v1')
      expect(sdk_config).to have_received(:default_model=).with('test-model')
      expect(sdk_config).to have_received(:debug=).with(false)
    end

    it 'does not configure the SDK without an API key' do
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).with('installation_configs').and_return(true)
      allow(InstallationConfig).to receive(:find_by).with(name: 'CAPTAIN_OPEN_AI_API_KEY')
        .and_return(instance_double(InstallationConfig, value: nil))
      allow(InstallationConfig).to receive(:find_by).with(name: 'CAPTAIN_OPEN_AI_MODEL')
        .and_return(instance_double(InstallationConfig, value: nil))
      allow(InstallationConfig).to receive(:find_by).with(name: 'CAPTAIN_OPEN_AI_ENDPOINT')
        .and_return(instance_double(InstallationConfig, value: nil))
      expect(Agents).not_to receive(:configure)

      described_class.configure
    end
  end
end
