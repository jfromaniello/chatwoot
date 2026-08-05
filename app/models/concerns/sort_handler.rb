module SortHandler
  extend ActiveSupport::Concern

  # status enum: open=0, resolved=1, pending=2, snoozed=3
  # Logical order for UI: open, pending, snoozed, resolved
  STATUS_SORT_ORDER = 'CASE conversations.status WHEN 0 THEN 0 WHEN 2 THEN 1 WHEN 3 THEN 2 WHEN 1 THEN 3 END ASC'.freeze

  class_methods do
    def sort_on_last_activity_at(sort_direction = :desc)
      order(generate_sql_query("#{SortHandler::STATUS_SORT_ORDER}, conversations.last_activity_at #{sort_direction.to_s.upcase}"))
    end

    def sort_on_created_at(sort_direction = :asc)
      order(generate_sql_query("#{SortHandler::STATUS_SORT_ORDER}, conversations.created_at #{sort_direction.to_s.upcase}"))
    end

    def sort_on_priority(sort_direction = :desc)
      order(generate_sql_query("#{SortHandler::STATUS_SORT_ORDER}, conversations.priority #{sort_direction.to_s.upcase} NULLS LAST, conversations.last_activity_at DESC"))
    end

    def sort_on_priority_created_at(sort_direction = :desc)
      order(generate_sql_query("#{SortHandler::STATUS_SORT_ORDER}, conversations.priority #{sort_direction.to_s.upcase} NULLS LAST, conversations.created_at ASC"))
    end

    def sort_on_waiting_since(sort_direction = :asc)
      order(generate_sql_query("#{SortHandler::STATUS_SORT_ORDER}, (conversations.waiting_since IS NULL), " \
                               "conversations.waiting_since #{sort_direction.to_s.upcase}, conversations.created_at ASC"))
    end

    def last_messaged_conversations
      Message.except(:order).select(
        'DISTINCT ON (conversation_id) conversation_id, id, created_at, message_type'
      ).order('conversation_id, created_at DESC')
    end

    def sort_on_last_user_message_at
      order('grouped_conversations.message_type', 'grouped_conversations.created_at ASC')
    end

    private

    def generate_sql_query(query)
      Arel::Nodes::SqlLiteral.new(sanitize_sql_for_order(query))
    end
  end
end
