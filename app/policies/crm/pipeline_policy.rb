module Crm
  class PipelinePolicy < ApplicationPolicy
    def index? = @account_user.present?
    def show? = index?
    def create? = @account_user&.administrator?
    def update? = create?
    def destroy? = create?

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(account_id: account.id)
      end
    end
  end
end
