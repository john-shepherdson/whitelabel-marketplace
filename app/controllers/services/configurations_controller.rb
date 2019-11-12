# frozen_string_literal: true

class Services::ConfigurationsController < Services::ApplicationController
  before_action :ensure_in_session!

  def show
    if wizard.step(:information, session[session_key]).valid?
      @step = step(session[session_key])
    else
      redirect_to service_offers_path(@service),
                  alert: "Please select one of the service offer"
    end
  end

  def update
    @step = step(configuration_params)

    if @step.request_voucher
      @step.voucher_id = ""
    end

    if @step.valid?
      save_in_session(@step)
      redirect_to service_summary_path(@service)
    else
      flash.now[:alert] = @step.error
      render :show
    end
  end

  private
    def configuration_params
      template = ProjectItem.new(session[session_key])
      session[session_key].
          merge(permitted_attributes(template)).
          merge(status: :created)
    end

    def step(attrs)
      wizard.step(:configuration, attrs)
    end
end
