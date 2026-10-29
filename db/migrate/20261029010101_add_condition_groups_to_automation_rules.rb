class AddConditionGroupsToAutomationRules < ActiveRecord::Migration[7.0]
  def change
    add_column :automation_rules, :condition_groups, :jsonb, null: false, default: []
  end
end
