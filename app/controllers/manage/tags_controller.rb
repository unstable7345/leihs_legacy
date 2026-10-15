class Manage::TagsController < Manage::ApplicationController

  def index
    @props = { tags: current_inventory_pool.tags.map { |t| tag_json(t) },
               create_path: manage_create_tag_path(current_inventory_pool),
               tags_path: manage_tags_path(current_inventory_pool) }
  end

  def create
    tag = current_inventory_pool.tags.new(name: params[:name])
    tag.color = params[:color] if params[:color].present?
    if tag.save
      render json: tag_json(tag), status: :ok
    else
      render json: { message: tag.errors.full_messages.join(', ') },
             status: :bad_request
    end
  end

  def update
    tag = current_inventory_pool.tags.find(params[:id])
    if tag.update(params.permit(:name, :color))
      render json: tag_json(tag), status: :ok
    else
      render json: { message: tag.errors.full_messages.join(', ') },
             status: :bad_request
    end
  end

  # the tag goes away from all its items too
  def destroy
    current_inventory_pool.tags.find(params[:id]).destroy!
    head :ok
  end

  private

  # NOTE: also reading and changing tags is for lending managers only
  def required_manager_role
    require_role :lending_manager, current_inventory_pool
  end

  def tag_json(tag)
    tag.as_json.merge(
      items_count: ApplicationRecord.connection.select_value(
        ApplicationRecord.sanitize_sql(
          ['SELECT count(*) FROM items_tags WHERE tag_id = ?', tag.id])).to_i)
  end

end
