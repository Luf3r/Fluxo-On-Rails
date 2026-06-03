# spec/requests/categories_spec.rb
require "rails_helper"

RSpec.describe "Categories", type: :request do
  let(:user) { create(:user) }
  let(:other) { create(:user) }

  before { sign_in user }

  describe "GET /categories" do
    let!(:system_category) { create(:category, :system, name: "Outros") }
    let!(:custom_category) { create(:category, user: user, name: "Viagens") }
    let!(:other_category) { create(:category, user: other, name: "Privada") }

    it "returns system and current user's categories" do
      get categories_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(system_category.display_name)
      expect(response.body).to include(custom_category.name)
      expect(response.body).not_to include(other_category.name)
    end

    it "renders the Portuguese category page without missing translations" do
      get categories_path(locale: :"pt-BR")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Categorias")
      expect(response.body).not_to include("translation missing")
      expect(response.body).not_to include("Translation missing")
    end

    it "localizes only system category names" do
      create(:category, :system, name: "Mercado", category_type: "expense")
      custom_category = create(:category, user: user, name: "Mercado pessoal")

      get categories_path(locale: :en)

      expect(response.body).to include("Groceries")
      expect(response.body).to include(custom_category.name)
    end
  end

  describe "POST /categories" do
    let(:valid_params) do
      {
        category: {
          name: "Moradia",
          category_type: "expense",
          budget_amount: "1200.00"
        }
      }
    end

    it "creates a custom category for the current user" do
      expect { post categories_path, params: valid_params }
        .to change { user.categories.count }.by(1)

      expect(user.categories.last).to have_attributes(
        name: "Moradia",
        category_type: "expense",
        budget_amount: 1200.00
      )
    end

    it "creates a sub-category below an accessible parent" do
      parent = create(:category, user: user, name: "Casa")

      expect {
        post categories_path, params: {
          category: valid_params[:category].merge(name: "Aluguel", parent_id: parent.id)
        }
      }.to change { parent.sub_categories.count }.by(1)
    end

    it "rejects another user's parent category" do
      other_parent = create(:category, user: other, name: "Other parent")

      expect {
        post categories_path, params: {
          category: valid_params[:category].merge(parent_id: other_parent.id)
        }
      }.not_to change(Category, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /categories/:id" do
    it "updates the current user's category" do
      category = create(:category, user: user, name: "Casa")

      patch category_path(category), params: {
        category: { name: "Casa fixa", category_type: "expense", budget_amount: "1500.00" }
      }

      expect(category.reload).to have_attributes(
        name: "Casa fixa",
        budget_amount: 1500.00
      )
    end

    it "rejects updating another user's category" do
      category = create(:category, user: other, name: "Privada")

      patch category_path(category), params: {
        category: { name: "Tentativa", category_type: "expense" }
      }

      expect(response).to have_http_status(:not_found)
      expect(category.reload.name).to eq("Privada")
    end
  end

  describe "DELETE /categories/:id" do
    it "destroys the current user's custom category" do
      category = create(:category, user: user)

      expect { delete category_path(category) }
        .to change(Category, :count).by(-1)
    end

    it "does not destroy system categories" do
      category = create(:category, :system, name: "Outros")

      expect { delete category_path(category) }
        .not_to change(Category, :count)

      expect(response).to redirect_to(categories_path)
    end
  end
end
