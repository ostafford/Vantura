require "rails_helper"

RSpec.describe "Projects", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /projects" do
    let!(:owned_project) { create(:project, owner: user) }
    let!(:member_project) do
      project = create(:project, owner: other_user)
      create(:project_member, project: project, user: user)
      project
    end
    let!(:other_project) { create(:project, owner: other_user) }

    it "shows all projects user owns or is a member of" do
      get "/projects"

      expect(response).to have_http_status(:success)
      project_ids = assigns(:projects).map(&:id)
      expect(project_ids).to include(owned_project.id, member_project.id)
      expect(project_ids).not_to include(other_project.id)
    end
  end

  describe "GET /projects/:id" do
    let(:project) { create(:project, owner: user) }

    it "shows the project" do
      get "/projects/#{project.id}"

      expect(response).to have_http_status(:success)
      expect(assigns(:project)).to eq(project)
    end

    context "when user is a member" do
      let(:project) do
        p = create(:project, owner: other_user)
        create(:project_member, project: p, user: user)
        p
      end

      it "allows access" do
        get "/projects/#{project.id}"
        expect(response).to have_http_status(:success)
      end
    end

    context "when user is not a member or owner" do
      let(:project) { create(:project, owner: other_user) }

      it "prevents access" do
        get "/projects/#{project.id}"
        expect(response).to redirect_to(projects_path)
        expect(flash[:alert]).to include("don't have access")
      end
    end
  end

  describe "GET /projects/new" do
    it "shows the new project form" do
      get "/projects/new"
      expect(response).to have_http_status(:success)
      expect(assigns(:project)).to be_a_new(Project)
    end
  end

  describe "POST /projects" do
    context "with valid parameters" do
      it "creates a new project" do
        expect {
          post "/projects",
               params: {
                 project: {
                   name: "Test Project",
                   description: "Test Description",
                   color: "#FF0000"
                 }
               }
        }.to change(Project, :count).by(1)

        project = Project.last
        expect(project.name).to eq("Test Project")
        expect(project.description).to eq("Test Description")
        expect(project.color).to eq("#FF0000")
        expect(project.owner).to eq(user)
        expect(response).to redirect_to(project_path(project))
        expect(flash[:notice]).to include("created successfully")
      end
    end

    context "with invalid parameters" do
      it "does not create a project and renders new" do
        expect {
          post "/projects",
               params: {
                 project: {
                   name: ""
                 }
               }
        }.not_to change(Project, :count)

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe "GET /projects/:id/edit" do
    let(:project) { create(:project, owner: user) }

    it "shows the edit form for owner" do
      get "/projects/#{project.id}/edit"
      expect(response).to have_http_status(:success)
      expect(assigns(:project)).to eq(project)
    end

    context "when user is not the owner and cannot edit" do
      let(:project) do
        p = create(:project, owner: other_user)
        create(:project_member, project: p, user: user, can_edit: false)
        p
      end

      it "prevents access" do
        get "/projects/#{project.id}/edit"
        expect(response).to redirect_to(project_path(project))
        expect(flash[:alert]).to include("don't have permission to edit")
      end
    end
  end

  describe "PATCH /projects/:id" do
    let(:project) { create(:project, owner: user, name: "Old Name") }

    context "with valid parameters" do
      it "updates the project" do
        patch "/projects/#{project.id}",
              params: {
                project: {
                  name: "New Name",
                  description: "New Description"
                }
              }

        project.reload
        expect(project.name).to eq("New Name")
        expect(project.description).to eq("New Description")
        expect(response).to redirect_to(project_path(project))
        expect(flash[:notice]).to include("updated successfully")
      end
    end

    context "with invalid parameters" do
      it "does not update and renders edit" do
        patch "/projects/#{project.id}",
              params: {
                project: {
                  name: ""
                }
              }

        project.reload
        expect(project.name).to eq("Old Name")
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end

    context "when user cannot edit" do
      let(:project) do
        p = create(:project, owner: other_user)
        create(:project_member, project: p, user: user, can_edit: false)
        p
      end

      it "prevents update" do
        patch "/projects/#{project.id}",
              params: {
                project: {
                  name: "Hacked Name"
                }
              }

        project.reload
        expect(project.name).not_to eq("Hacked Name")
        expect(response).to redirect_to(project_path(project))
        expect(flash[:alert]).to include("don't have permission to edit")
      end
    end
  end

  describe "DELETE /projects/:id" do
    let!(:project) { create(:project, owner: user) }

    context "when user is owner" do
      it "deletes the project" do
        expect {
          delete "/projects/#{project.id}"
        }.to change(Project, :count).by(-1)

        expect(response).to redirect_to(projects_path)
        expect(flash[:notice]).to include("deleted successfully")
      end
    end

    context "when user cannot delete" do
      let(:project) do
        p = create(:project, owner: other_user)
        create(:project_member, project: p, user: user, can_delete: false)
        p
      end

      it "prevents deletion" do
        expect {
          delete "/projects/#{project.id}"
        }.not_to change(Project, :count)

        expect(response).to redirect_to(project_path(project))
        expect(flash[:alert]).to include("don't have permission to delete")
      end
    end
  end
end
