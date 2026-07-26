# frozen_string_literal: true

module PosShellHelper
  # Resolve the operational session for register header context.
  def pos_shell_session
    return @open_session if defined?(@open_session) && @open_session
    return @pos_transaction.active_pos_session if @pos_transaction&.active_pos_session
    return @pos_transaction.origin_pos_session if @pos_transaction&.origin_pos_session

    nil
  end

  def pos_shell_presentation
    @presentation_state.presence || @workspace&.state.presence || "ready"
  end

  def pos_shell_presentation_label
    @workspace&.label.presence || pos_shell_presentation.to_s.humanize
  end
end
