# frozen_string_literal: true

class Api::V1::Accounts::InboxEvolutionConfigurationController < Api::V1::Accounts::BaseController
  before_action :set_inbox
  rescue_from CustomExceptions::Evolution do |error|
    render json: { error: error.message, error_code: error.code }, status: error.http_status
  end

  def show
    authorize @inbox, :show?
    render json: Evolution::ChatwootConfiguration.new(@inbox).show
  end

  def update
    authorize @inbox, :update?
    sign_msg = params[:sign_msg]
    unless [true, false].include?(sign_msg)
      return render json: { error: I18n.t('evolution_groups.errors.invalid_sign_msg') }, status: :unprocessable_entity
    end

    render json: Evolution::ChatwootConfiguration.new(@inbox).update_sign_msg(sign_msg)
  end

  private

  def set_inbox
    @inbox = Current.account.inboxes.find(params[:inbox_id])
    return if @inbox.api?

    return head :not_found
  end
end
