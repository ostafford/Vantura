require "application_system_test_case"

class A11ySmokeTest < ApplicationSystemTestCase
  test "pages expose skip link and main landmark" do
    visit root_path
    assert_selector("a.skip-link", visible: :all)
    assert_selector("main#main", visible: :all)
  end
end

