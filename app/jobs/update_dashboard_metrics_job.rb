# app/jobs/update_dashboard_metrics_job.rb
class UpdateDashboardMetricsJob < ApplicationJob
  queue_as :default

  def perform
    metrics = DashboardMetricsCalculator.call
    DashboardMetric.create!(metrics)
  rescue StandardError => e
    Rails.logger.error "Failed to update dashboard metrics: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end
end