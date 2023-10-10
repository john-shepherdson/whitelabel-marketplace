# frozen_string_literal: true

module Viewable
  extend ActiveSupport::Concern

  included do
    before_validation :assign_analytics, if: :key_present?

    def id_construct(obj = self)
      %i[id pid slug]
        .select { |id| obj.respond_to?(id) && obj.send(id).present? }
        .map { |mtd| obj.send(mtd) }
        .join("|")
        .downcase
    end

    def path_pattern
      case self
      when Bundle
        "#{id_construct(service)}\/bundles\/" + "#{iid}[$|\??|]"
      else
        "#{self.class.name.pluralize.downcase}\/#{id_construct}"
      end
    end

    def analytics
      @client =
        !@client.respond_to?(:credentials) || @client&.credentials&.expires_at&.blank? ? Google::Analytics.new : @client
      Rails
        .cache
        .fetch("#{self.class.name}-#{id}-analytics", expires_in: Mp::Application.config.resource_cache_ttl) do
          Analytics::PageViewsAndRedirects.new(@client).call(path_pattern)
        end
    rescue StandardError
      Rails.logger.warn "#{self.class.name} (#{id_construct}) analytics cannot be updated. Return default"
      { views: usage_counts_views, redirects: 0 }
    end

    def assign_analytics
      previous_cache = usage_counts_views
      self.usage_counts_views = analytics[:views].to_i if analytics[:views].respond_to?(:to_i)
      update_offers
      Rails.logger.info "Assigned to #{self} #{name} (#{id_construct}) " +
                          "usage_counts_views: #{previous_cache} => #{usage_counts_views} (#{analytics[:views]})"
    end

    def store_analytics
      transaction do
        if analytics[:views].is_a?(Integer) && usage_counts_views != analytics[:views]
          update_columns(usage_counts_views: analytics[:views])
          update_offers
          Rails.logger.info "#{usage_counts_views} usage_counts_views stored to #{self} #{name} (#{id_construct})"
        end
      end
    end

    def update_offers
      if self.class.in? [Service, Datasource]
        offers.each { |o| o.update_column(:usage_counts_views, usage_counts_views) if o.valid? }
      end
    end

    def key_present?
      state = File.open("#{Rails.root}/#{Rails.configuration.google_api_key_path}")&.present?
      @client ||= state ? Google::Analytics.new : @client
      state
    rescue Errno::ENOENT
      Rails.logger.info "Google API key not provided. Omitting update cache callback"
      state
    end
  end
end
