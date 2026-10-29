module Crm
  class DealPolicy < ApplicationPolicy
    def index? = @account_user.present?
    def show? = index?
    def create? = index?
    def update? = index?
    def destroy? = @account_user&.administrator?

    class Scope < ApplicationPolicy::Scope
      # A plain agent only sees the cards they own; administrators and agents with a custom role see the whole account.
      def resolve
        deals = scope.where(account_id: account.id)
        account_user&.own_records_only? ? deals.where(owner_id: user.id) : deals
      end
    end
  end
end
