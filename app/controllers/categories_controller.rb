# frozen_string_literal: true

class CategoriesController < AuthenticatedController
  before_action :set_category, only: %i[edit update]
  before_action :set_destroy_category, only: :destroy
  before_action :set_parent_categories, only: %i[new edit create update]

  def index
    @custom_categories = current_user.categories.includes(:parent).order(:name)
    @system_categories = Category.system.order(:name)
  end

  def new
    @category = current_user.categories.build(category_type: "expense")
  end

  def edit
  end

  def create
    @category = current_user.categories.build(category_attributes)
    assign_parent(@category)

    if @category.save
      redirect_to categories_path, notice: t("finance.categories.notices.created")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    @category.assign_attributes(category_attributes)
    assign_parent(@category)

    if @category.save
      redirect_to categories_path, notice: t("finance.categories.notices.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @category.destroy
      redirect_to categories_path, notice: t("finance.categories.notices.destroyed")
    else
      redirect_to categories_path, alert: t("finance.categories.notices.destroy_failed")
    end
  end

  private

  def set_category
    @category = current_user.categories.find(params[:id])
  end

  def set_destroy_category
    @category = Category.options_for_user(current_user).find(params[:id])
  end

  def set_parent_categories
    @parent_categories = Category.options_for_user(current_user)
      .where(parent_id: nil)
      .where.not(id: @category&.id)
      .left_outer_joins(:transactions)
      .where(transactions: { id: nil })
      .order(system: :desc, name: :asc)
  end

  def assign_parent(category)
    parent_id = category_params[:parent_id].presence
    category.parent = parent_id ? Category.options_for_user(current_user).find(parent_id) : nil
  end

  def category_attributes
    category_params.except(:parent_id)
  end

  def category_params
    params.require(:category).permit(:name, :category_type, :budget_amount, :parent_id)
  end
end
