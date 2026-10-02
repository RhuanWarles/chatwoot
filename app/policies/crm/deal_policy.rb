module Crm
  class DealPolicy < ApplicationPolicy
    def index? = @account_user.present?
    def show? = index?
    def create? = index?
    def update? = index?
    def destroy? = @account_user&.administrator?

    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.where(account_id: account.id)
      end
    end
  end
end
