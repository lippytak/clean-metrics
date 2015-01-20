class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_filter :generate_metrics

  def generate_metrics
    # Get data from google spreadsheet
    session = GoogleDrive.login(ENV['GOOGLE_DRIVE_EMAIL'], ENV['GOOGLE_DRIVE_PASSWORD'])
    ws = session.spreadsheet_by_key(ENV['CLEAN_METRICS_SPREADSHEET_KEY']).worksheets[0]

    headers = ws.rows[0]
    headers_index = Hash[headers.map.with_index.to_a]
    app_date_column_index = headers_index['app_date']
    cumulative_app_col_index = headers_index['cumulative_apps']
    cumulative_approved_app_col_index = headers_index['cumulative_approved_apps']

    # Funnel
    last_step_col_index = headers_index['last_completed_step']
    @total_per_step = Hash.new(0)
    ws.rows[2..-1].each do |r|
      step = r[last_step_col_index]
      @total_per_step[step] += 1
    end

    @total_per_step['submitted all verifications'] += @total_per_step['approved']
    @total_per_step['determined eligible'] += @total_per_step['submitted all verifications']
    @total_per_step['completed interview'] += @total_per_step['determined eligible']
    @total_per_step['scheduled interview'] += @total_per_step['completed interview']
    @total_per_step['cleared'] += @total_per_step['scheduled interview']
    @total_per_step['submitted'] += @total_per_step['cleared']

    @funnel = { "funnel" => [
      {"name"=> "submitted", "value"=> @total_per_step['submitted']},
      {"name"=> "cleared", "value"=> @total_per_step['cleared']},
      {"name"=> "scheduled interview", "value"=> @total_per_step['scheduled interview']},
      {"name"=> "completed interview", "value"=> @total_per_step['completed interview']},
      {"name"=> "determined eligible", "value"=> @total_per_step['determined eligible']},
      {"name"=> "submitted all verifications", "value"=> @total_per_step['submitted all verifications']},
      {"name"=> "approved", "value"=> @total_per_step['approved']}]
    }

    # Timeseries
    @app_dates = []
    @cumulative_apps = []
    @cumulative_approved_apps = []

    ws.rows[2..-1].each do |r|
      begin
        date = Date.strptime(r[app_date_column_index], "%m/%d/%Y")
      rescue
        next
      end
      if @app_dates.include? date
        @cumulative_apps[-1] = r[cumulative_app_col_index]  
        @cumulative_approved_apps[-1] = r[cumulative_approved_app_col_index]
      else
        @app_dates << date
        @cumulative_apps << r[cumulative_app_col_index]
        @cumulative_approved_apps << r[cumulative_approved_app_col_index]
      end
    end
  end

  def index

  end

  def submitted_apps
    # Docs: https://dev.ducksboard.com/apidoc/slot-kinds/#absolute-graphs
    # Ducksboard takes timestamps
    app_timestamps = @app_dates.map { |d| d.to_time.to_i}
    data = []
    @cumulative_apps.each_with_index { |value, index|
      data << {'timestamp' => app_timestamps[index],
                'value' => value}
    }

    render :json => data
  end

  def approved_apps
    # Docs: https://dev.ducksboard.com/apidoc/slot-kinds/#absolute-graphs
    # Ducksboard takes timestamps
    app_timestamps = @app_dates.map { |d| d.to_time.to_i}
    data = []
    @cumulative_approved_apps.each_with_index { |value, index|
      data << {'timestamp' => app_timestamps[index],
                'value' => value}
    }
    render :json => data
  end

  def approval_rate
    # Docs: https://dev.ducksboard.com/apidoc/slot-kinds/#absolute-graphs
    rate = @cumulative_approved_apps[-1].to_f / @cumulative_apps[-1].to_f
    render :json => {'value' => rate}
  end

  def total_approved_apps
    # Docs: https://dev.ducksboard.com/apidoc/slot-kinds/#absolute-graphs
    render :json => {'value' => @cumulative_approved_apps[-1]}
  end

  def funnel
    # Docs: https://dev.ducksboard.com/apidoc/slot-kinds/#funnels
    # {"value": {"funnel": [
    #      {"name": "STEP 1", "value": 1600},
    #      {"name": "STEP 2", "value": 1400},
    #      {"name": "STEP 3", "value": 1200},
    #      {"name": "STEP 4", "value": 900},
    #      {"name": "STEP 5", "value": 600},
    #      {"name": "STEP 6", "value": 330}]}}
    render :json => {'value' => @funnel}
  end
end