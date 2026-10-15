class Manage::TagsController < Manage::ApplicationController

  def create
    tag = current_inventory_pool.tags.new(name: params[:name])
    if tag.save
      render json: tag, status: :ok
    else
      render json: { message: tag.errors.full_messages.join(', ') },
             status: :bad_request
    end
  end

end
