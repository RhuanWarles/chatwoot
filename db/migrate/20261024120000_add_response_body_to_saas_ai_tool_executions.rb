class AddResponseBodyToSaasAiToolExecutions < ActiveRecord::Migration[7.2]
  def change
    add_column :saas_ai_tool_executions, :response_body, :text
  end
end
