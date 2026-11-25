class TagsController < ApplicationController
  def index
    prefix = params[:q].to_s.strip.first(40)
    @tags = prefix.present? ? Tag.starting_with(prefix).limit(12).pluck(:name) : []
    render json: { tags: @tags }
  end
end
