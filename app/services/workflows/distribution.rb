# Weighted round robin ("smooth" variant): over every 100 leads each person gets exactly their percentage, and the turns
# are spread out instead of coming in blocks. The running score of each person lives in a row per workflow step, so the
# count goes on between runs and starts over when the people or the percentages of the step change.
class Workflows::Distribution
  MAX_ASSIGNEES = 50

  class << self
    # Messages for an invalid list of { user_id, percentage }, without touching the database.
    def errors(assignees)
      return ['distribution needs at least one person'] unless assignees.is_a?(Array) && assignees.any?
      return ["distribution can have at most #{MAX_ASSIGNEES} people"] if assignees.size > MAX_ASSIGNEES
      return ['distribution entries must be objects'] unless assignees.all?(Hash)

      row_errors(assignees.map(&:with_indifferent_access))
    end

    # The id of the person who gets the next lead of this step.
    def pick!(workflow, node_id, assignees)
      weights = assignees.to_h { |item| [whole(item['user_id']), whole(item['percentage'])] }
      signature = weights.map { |id, weight| "#{id}:#{weight}" }.join(',')
      state = AutomationDistributionState.create_or_find_by!(automation_workflow_id: workflow.id, node_id: node_id.to_s) do |row|
        row.account_id = workflow.account_id
        row.signature = signature
      end
      state.with_lock { advance(state, weights, signature) }
    end

    private

    # Every rule with the messages it breaks, in the order the messages are shown.
    def row_errors(rows)
      {
        'every person of the distribution needs a user' => rows.all? { |row| whole(row[:user_id])&.positive? },
        'a person can only appear once in the distribution' => rows.pluck(:user_id).map(&:to_s).uniq.size == rows.size,
        'every percentage must be a whole number from 1 to 100' => rows.all? { |row| (1..100).cover?(whole(row[:percentage])) },
        'the percentages must add up to 100' => rows.sum { |row| whole(row[:percentage]).to_i } == 100
      }.reject { |_message, valid| valid }.keys
    end

    def advance(state, weights, signature)
      scores = state.signature == signature ? state.scores.dup : {}
      weights.each { |id, weight| scores[id.to_s] = scores.fetch(id.to_s, 0) + weight }
      chosen = weights.keys.max_by { |id| scores[id.to_s] }
      scores[chosen.to_s] -= weights.values.sum
      state.update!(signature: signature, scores: scores)
      chosen
    end

    def whole(value)
      Integer(value.to_s, exception: false)
    end
  end
end
