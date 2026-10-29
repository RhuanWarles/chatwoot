class AutomationWorkflowPolicy < ApplicationPolicy
  %i[index? create? show? update? destroy? run? runs?].each do |action|
    define_method(action) { @account_user.administrator? }
  end
end
