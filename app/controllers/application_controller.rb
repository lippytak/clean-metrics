class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  def index
    # Get data from google spreadsheet
    session = GoogleDrive.login(ENV['GOOGLE_DRIVE_EMAIL'], ENV['GOOGLE_DRIVE_PASSWORD'])
    ws = session.spreadsheet_by_key(ENV['CLEAN_METRICS_SPREADSHEET_KEY']).worksheets[0]

    headers = ws.rows[0]
    headers_index = Hash[headers.map.with_index.to_a]
    app_date_column_index = headers_index['app_date']
    cumulative_app_col_index = headers_index['cumulative_apps']
    cumulative_approved_app_col_index = headers_index['cumulative_approved_apps']
    app_status_col = headers_index['status']

    # Format for plotly
    app_dates = []
    cumulative_apps = []
    cumulative_approved_apps = []
    ws.rows[2..-1].each do |r|
      begin
        date = Date.strptime(r[app_date_column_index], "%m/%d/%Y")
      rescue
        next
      end
      if app_dates.include? date
        cumulative_apps[-1] = r[cumulative_app_col_index]  
        cumulative_approved_apps[-1] = r[cumulative_approved_app_col_index]
      else
        app_dates << date
        cumulative_apps << r[cumulative_app_col_index]
        cumulative_approved_apps << r[cumulative_approved_app_col_index]
      end
    end

    # Chartz!
    data = [
      {
        'name' => '# submitted apps',
        'type' => 'scatter',
        'x' => app_dates,
        'y' => cumulative_apps
      },
      {
        'name' => '# approved apps',
        'type' => 'bar',
        'x' => app_dates,
        'y' => cumulative_approved_apps
      }
    ]

    kwargs={
        "filename"=> "Clean Metrics",
        "fileopt"=> "overwrite",
        "style"=> {
        "type"=> "scatter"
        },
          "layout"=> {
          "title"=> "Clean Metrics",
          "yaxis" => {"title" => "# of applications"},
        },
        "world_readable"=> true
      }
    @submitted_apps_plot_url = view_context.create_plot("plot", data, kwargs)
  end
end