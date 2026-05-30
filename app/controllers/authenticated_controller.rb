class AuthenticatedController < ApplicationController
  before_action :authenticate_user!

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  private

  def render_not_found
    head :not_found
  end
end
