class Api::V1::Accounts::Conversations::MessagesController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_api_inbox, only: :update

  def index
    @messages = message_finder.perform
  end

  def create
    user = Current.user || @resource
    mb = Messages::MessageBuilder.new(user, @conversation, params)
    @message = mb.perform
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def update
    Messages::StatusUpdateService.new(message, permitted_params[:status], permitted_params[:external_error]).perform
    @message = message
  end

  def destroy
    ActiveRecord::Base.transaction do
      message.update!(content: I18n.t('conversations.messages.deleted'), content_type: :text, content_attributes: { deleted: true })
      message.attachments.destroy_all
    end
  end

  def retry
    return if message.blank?

    service = Messages::StatusUpdateService.new(message, 'sent')
    service.perform
    message.update!(content_attributes: {})
    ::SendReplyJob.perform_later(message.id)
  rescue StandardError => e
    render_could_not_create_error(e.message)
  end

  def execute_action
    agent_bot = find_agent_bot_for_action
    return head :not_found if agent_bot.blank? || agent_bot.outgoing_url.blank?

    payload = message.webhook_data.merge(
      event: 'message_action_executed',
      action_payload: params[:action_payload]
    )

    AgentBots::WebhookJob.perform_later(
      agent_bot.outgoing_url, payload, :agent_bot_webhook,
      secret: agent_bot.secret, delivery_id: SecureRandom.uuid
    )

    message.update!(content_attributes: message.content_attributes.merge('dismissed' => true)) if message.content_attributes['dismiss_on_action']

    @message = message
  end

  def dismiss
    message.update!(content_attributes: message.content_attributes.merge(dismissed: true))
    @message = message
  end

  def translate
    return head :ok if already_translated_content_available?

    translated_content = Integrations::GoogleTranslate::ProcessorService.new(
      message: message,
      target_language: permitted_params[:target_language]
    ).perform

    if translated_content.present?
      translations = {}
      translations[permitted_params[:target_language]] = translated_content
      translations = message.translations.merge!(translations) if message.translations.present?
      message.update!(translations: translations)
    end

    render json: { content: translated_content }
  rescue Google::Cloud::Error => e
    # `details` carries the clean human message; `message` includes gRPC debug noise
    render_could_not_create_error(e.details.presence || e.message)
  end

  private

  def message
    @message ||= @conversation.messages.find(permitted_params[:id])
  end

  def message_finder
    @message_finder ||= MessageFinder.new(@conversation, params)
  end

  def permitted_params
    params.permit(:id, :target_language, :status, :external_error)
  end

  def find_agent_bot_for_action
    # First priority: the bot that sent this message
    return message.sender if message.sender_type == 'AgentBot'

    # Fallback: bot assigned to conversation or inbox
    agent_bots_for_conversation.first
  end

  def agent_bots_for_conversation
    bots = []
    bots << @conversation.assignee_agent_bot if @conversation.assignee_agent_bot.present?
    inbox_bot = @conversation.inbox.agent_bot if @conversation.inbox.agent_bot_inbox&.active?
    bots << inbox_bot if inbox_bot.present?
    bots.compact.uniq
  end

  def already_translated_content_available?
    message.translations.present? && message.translations[permitted_params[:target_language]].present?
  end

  # API inbox check
  def ensure_api_inbox
    # Only API inboxes can update messages
    render json: { error: 'Message status update is only allowed for API inboxes' }, status: :forbidden unless @conversation.inbox.api?
  end
end
