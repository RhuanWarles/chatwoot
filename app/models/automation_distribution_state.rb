# == Schema Information
#
# Table name: automation_distribution_states
#
#  id                     :bigint           not null, primary key
#  node_id                :string           not null
#  scores                 :jsonb            not null
#  signature              :string           not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  account_id             :bigint           not null
#  automation_workflow_id :bigint           not null
#
# Indexes
#
#  idx_automation_distribution_workflow_node                (automation_workflow_id,node_id) UNIQUE
#  index_automation_distribution_states_on_account_id       (account_id)
#
class AutomationDistributionState < ApplicationRecord
  belongs_to :account
  belongs_to :automation_workflow
end
