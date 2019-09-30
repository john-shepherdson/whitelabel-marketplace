# frozen_string_literal: true

require "rails_helper"

RSpec.feature "Services in backoffice" do
  include OmniauthHelper

  context "As a service portolio manager" do
    let(:user) { create(:user, roles: [:service_portfolio_manager]) }

    before { checkin_sign_in_as(user) }

    scenario "I can see all services" do
      create(:service, title: "service1")
      create(:service, title: "service2")

      visit backoffice_services_path

      expect(page).to have_content("service1")
      expect(page).to have_content("service2")
    end

    scenario "I can see any service" do
      service = create(:service, title: "service1")

      visit backoffice_service_path(service)

      expect(page).to have_content("service1")
    end

    scenario "I can create new service" do
      category = create(:category)
      provider = create(:provider)
      research_area = create(:research_area)
      platform = create(:platform)
      target_group = create(:target_group)

      visit backoffice_services_path
      click_on "Create new Service"

      fill_in "Title", with: "service title"
      fill_in "Description", with: "service description"
      fill_in "Terms of use", with: "service terms of use"
      fill_in "Tagline", with: "service tagline"
      fill_in "Service website", with: "https://sample.url"
      fill_in "Places", with: "Europe"
      fill_in "Languages", with: "English"
      select target_group.name, from: "Dedicated For"
      fill_in "Terms of use url", with: "https://sample.url"
      fill_in "Access policies url", with: "https://sample.url"
      fill_in "Sla url", with: "https://sample.url"
      fill_in "Webpage url", with: "https://sample.url"
      fill_in "Manual url", with: "https://sample.url"
      fill_in "Helpdesk url", with: "https://sample.url"
      fill_in "Tutorial url", with: "https://sample.url"
      fill_in "Restrictions", with: "Reaserch affiliation needed"
      fill_in "Activate message", with: "Welcome!!!"
      fill_in "Service Order Target", with: "email@domain.com"
      select "Alpha (min. TRL 5)", from: "Phase"
      select research_area.name, from: "Research areas"
      select provider.name, from: "Providers"
      select "open_access", from: "Service type"
      select platform.name, from: "Platforms"
      fill_in "service_contact_emails_0", with: "person1@test.ok"
      # page.find("#add-email-field").click
      # fill_in "service_contact_emails_1", with: "person2@test.ok"
      select category.name, from: "Categories"
      select user.to_s, from: "Owners"

      fill_in "service_sources_attributes_0_eid", with: "12345a"

      expect { click_on "Create Service" }.
        to change { user.owned_services.count }.by(1)


      expect(user.owned_services.last.order_target).to eq("email@domain.com")

      expect(page).to have_content("service title")
      expect(page).to have_content("service description")
      expect(page).to have_content("service tagline")
      expect(page).to have_content("https://sample.url")
      expect(page).to have_content("open_access")
      expect(page).to have_content("person1@test.ok")
      # expect(page).to have_content("person2@test.ok")
      expect(page).to have_content("Welcome!!!")
      expect(page).to have_content(research_area.name)
      expect(page).to have_content(target_group.name)
      expect(page).to have_content(category.name)
      expect(page).to have_content("Publish")
      expect(page).to have_content("eic: 12345a")
      expect(page).to have_content("Alpha (min. TRL 5)")
    end

    scenario "I cannot create service with wrong logo file" do
      provider = create(:provider)
      research_area = create(:research_area)

      visit backoffice_services_path
      click_on "Create new Service"

      attach_file("service_logo", "spec/lib/images/invalid-logo.svg")
      fill_in "Title", with: "service title"
      fill_in "Description", with: "service description"
      fill_in "Tagline", with: "service tagline"
      select research_area.name, from: "Research areas"
      select provider.name, from: "Providers"

      expect { click_on "Create Service" }.
        to change { user.owned_services.count }.by(0)

      expect(page).to have_content("Sorry, but the logo format you were trying to attach is not supported in the Marketplace.")
    end

    scenario "I can publish service" do
      service = create(:service, status: :draft)

      visit backoffice_service_path(service)
      click_on "Publish"

      expect(page).to have_content("Status: published")
    end

    scenario "I can publish as unverified service" do
      service = create(:service, status: :draft)

      visit backoffice_service_path(service)
      click_on "Publish as unverified service"

      expect(page).to have_content("Status: unverified")
    end

    scenario "I can unpublish service" do
      service = create(:service, status: :published)

      visit backoffice_service_path(service)
      click_on "Stop showing in the MP"

      expect(page).to have_content("Status: draft")
    end

    scenario "I can edit any service" do
      service = create(:service, title: "my service")

      visit backoffice_service_path(service)
      click_on "Edit"

      fill_in "Title", with: "updated title"
      click_on "Update Service"

      expect(page).to have_content("updated title")
    end

    scenario "I can add new offer", js: true do
      service = create(:service, title: "my service", owners: [user])

      visit backoffice_service_path(service)
      click_on "Add new offer", match: :first

      expect {
        fill_in "Name", with: "new offer 1"
        fill_in "Description", with: "test offer"
        fill_in "offer_parameters_as_string_0",
                with: "{" \
                      "\"id\":\"id1\"," \
                      "\"type\":\"select\"," \
                      "\"label\":\"Number of CPU Cores\"," \
                      "\"config\":{\"mode\":\"buttons\"," \
                      "\"values\":[\"1\", \"2\", \"4\", \"8\"]}," \
                      "\"value_type\":\"integer\"," \
                      "\"description\":\"Select number of cores you want\"}"

        click_on "Create Offer"
      }.to change { service.offers.count }.by(1)

      expect(page).to have_content("test offer")
      expect(service.offers.last.name).to eq("new offer 1")
    end

    scenario "Offer are converted from markdown to html on service view" do
      offer = create(:offer,
                     name: "offer1",
                     description: "# Test offer\r\n\rDescription offer")

      visit backoffice_service_path(offer.service)

      find(".card-body h1", text: "Test offer")
      find(".card-body p", text: "Description offer")
    end

    scenario "I cannot add invalid offer", js: true do
      service = create(:service, title: "my service", owners: [user])

      visit backoffice_service_path(service)
      click_on "Add new offer", match: :first

      expect {
        fill_in "Name", with: "new offer"
        fill_in "Description", with: "test offer"
        fill_in "offer_parameters_as_string_0",
                with: "random text!"
        click_on "Create Offer"
      }.to change { service.offers.count }.by(0)
    end

    scenario "I can edit offer", js: true do
      service = create(:service, title: "my service", status: :draft)
      offer = create(:offer, name: "offer1", description: "desc", service: service,
                     parameters: [{
                                  "id": "id1",
                                  "type": "select",
                                  "label": "Number of CPU Cores",
                                  "config": { "mode": "buttons",
                                  "values": [1, 2, 4, 8] },
                                  "value_type": "integer",
                                  "description": "Select number of cores you want"
                                  }])

      visit backoffice_service_path(service)
      click_on(class: "edit-offer")

      fill_in "Description", with: "new desc"
      click_on "Update Offer"

      expect(page).to have_content("new desc")
      expect(offer.reload.description).to eq("new desc")
    end

    scenario "I can delete existed parameters", js: true do
      service = create(:service, title: "my service", status: :draft)
      offer = create(:offer, name: "offer1", description: "desc", service: service,
                     parameters: [{ "id": "id1",
                                    "type": "select",
                                    "label": "Number of CPU Cores",
                                    "config": { "mode": "buttons",
                                    "values": [1, 2, 4, 8] },
                                    "value_type": "integer",
                                    "description": "Select number of cores you want" },
                                  { "id": "id2",
                                    "type": "select",
                                    "label": "Number of CPU Cores",
                                    "config": { "mode": "buttons",
                                    "values": [1, 2, 4, 8] },
                                    "value_type": "integer",
                                    "description": "Select number of cores you want" }])

      visit backoffice_service_path(service)
      click_on(class: "edit-offer")

      fill_in "offer_parameters_as_string_0", with: ""
      fill_in "offer_parameters_as_string_1", with: ""
      click_on "Update Offer"

      expect(offer.reload.parameters).to eq([])
    end

    scenario "I cannot create parameters with two identical ids", js: true do
      service = create(:service, title: "my service", status: :draft)
      expect {
        create(:offer, name: "offer1", description: "desc", service: service,
                     parameters: [{ "id": "id1",
                                    "type": "select",
                                    "label": "Number of CPU Cores",
                                    "config": { "mode": "buttons",
                                    "values": [1, 2, 4, 8] },
                                    "value_type": "integer",
                                    "description": "Select number of cores you want" },
                                  { "id": "id1",
                                    "type": "select",
                                    "label": "Number of CPU Cores",
                                    "config": { "mode": "buttons",
                                    "values": [1, 2, 4, 8] },
                                    "value_type": "integer",
                                    "description": "Select number of cores you want" }])
      }.to raise_error(ActiveRecord::RecordInvalid)
    end


    scenario "I can delete offer" do
      service = create(:service, title: "my service", status: :draft)
      _offer = create(:offer, name: "offer1", description: "desc", service: service)

      visit backoffice_service_path(service)
      click_on(class: "delete-offer")

      expect(page).to have_content("This service has no offers")
    end

    scenario "I can see info if service has no offer" do
      service = create(:service, title: "my service")

      visit backoffice_service_path(service)

      expect(page).to have_content("This service has no offers")
    end

    scenario "I can change offer status from published to draft" do
      offer = create(:offer)

      visit backoffice_service_path(offer.service)
      click_on "Stop showing offer"

      expect(offer.reload.status).to eq("draft")
    end

    scenario "I can change offer status from draft to publish" do
      offer = create(:offer, status: :draft)

      visit backoffice_service_path(offer.service)
      click_on "Publish offer"

      expect(offer.reload.status).to eq("published")
    end

    scenario "I can change service status from publish to draft" do
      service = create(:service, title: "my service")

      visit backoffice_service_path(service)
      click_on("Stop showing in the MP")

      expect(page).to have_selector(:link_or_button, "Publish")
    end

    scenario "I can change external id of the service" do
      service = create(:service, title: "my service")
      _external_source = create(:service_source, eid: "777", source_type: "eic", service: service)

      visit backoffice_service_path(service)
      click_on "Edit"

      expect(page).to have_content("777")
      fill_in "service_sources_attributes_0_eid", with: "12345a"
      click_on "Update Service"
      expect(page).to have_content("eic: 12345a")
    end

    scenario "I can change upstream" do
      service = create(:service, title: "my service")
      external_source = create(:service_source, service: service)

      visit backoffice_service_path(service)
      click_on "Edit"

      select external_source.to_s, from: "Service Upstream"
      click_on "Update Service"
      expect(page).to have_content(external_source.to_s, count: 2)
    end
  end

  context "as a service owner" do
    let(:user) { create(:user) }

    before { checkin_sign_in_as(user) }

    scenario "I can edit service draft" do
      service = create(:service, owners: [user], status: :draft)

      visit backoffice_service_path(service)
      click_on "Edit"

      fill_in "Title", with: "Owner can edit service draft"
      click_on "Update Service"
      expect(page).to have_content("Owner can edit service draft")
    end

    scenario "I can create new offer" do
      service = create(:service, owners: [user])

      visit backoffice_service_path(service)
      click_on "Add new offer", match: :first

      fill_in "Name", with: "New offer"
      fill_in "Description", with: "New fancy offer"
      click_on "Create Offer"

      expect(page).to have_content("New offer")
      expect(page).to have_content("New fancy offer")
    end
  end
end
