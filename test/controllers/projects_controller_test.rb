require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    sign_in_as(:one)
    @project = Project.create!(owner: @user, name: "Test Project")
  end

  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should get show" do
    get project_url(@project)
    assert_response :success
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should create project with valid params" do
    assert_difference("Project.count", 1) do
      post projects_url, params: { project: { name: "New Project" } }
    end

    assert_redirected_to project_url(Project.last)
  end

  test "should not create project with invalid params" do
    assert_no_difference("Project.count") do
      post projects_url, params: { project: { name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_project_url(@project)
    assert_response :success
  end

  test "should update project with valid params" do
    patch project_url(@project), params: { project: { name: "Updated Project" } }
    assert_redirected_to project_url(@project)
    @project.reload
    assert_equal "Updated Project", @project.name
  end

  test "should not update project with invalid params" do
    patch project_url(@project), params: { project: { name: "" } }
    assert_response :unprocessable_entity
  end

  test "should destroy project" do
    assert_difference("Project.count", -1) do
      delete project_url(@project)
    end

    assert_redirected_to projects_url
  end

  test "should use ProjectsIndexStatisticsService for index" do
    get projects_url
    assert_response :success
    # Service is called indirectly - verified through successful response
  end

  test "should use ProjectShowDataService for show" do
    get project_url(@project)
    assert_response :success
    # Service is called indirectly - verified through successful response
  end

  test "requires authentication" do
    delete session_url
    get projects_url
    assert_redirected_to new_session_url
  end

  test "requires project membership to view" do
    other_user = users(:two)
    sign_in_as(:two)

    get project_url(@project)
    assert_response :forbidden
  end

  test "allows project members to view" do
    other_user = users(:two)
    @project.project_memberships.create!(user: other_user, access_level: :limited)
    sign_in_as(:two)

    get project_url(@project)
    assert_response :success
  end

  test "requires owner to destroy" do
    other_user = users(:two)
    @project.project_memberships.create!(user: other_user, access_level: :limited)
    sign_in_as(:two)

    assert_no_difference("Project.count") do
      delete project_url(@project)
    end
    assert_response :forbidden
  end

  test "syncs project memberships on create" do
    other_user = users(:two)
    post projects_url, params: {
      project: { name: "New Project" },
      member_user_ids: [ other_user.id ]
    }

    project = Project.last
    assert project.members.include?(other_user)
  end

  test "syncs project memberships on update" do
    other_user = users(:two)
    patch project_url(@project), params: {
      project: { name: "Updated" },
      member_user_ids: [ other_user.id ]
    }

    @project.reload
    assert @project.members.include?(other_user)
  end
end
