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
    status_column_index = headers_index['status']

    # Get data into hash
    submitted_app_dates = []
    approved_app_dates = []
    ws.rows[2..-1].each do |r|
      date = Date.strptime(r[app_date_column_index], "%m/%d/%Y")
      status = r[status_column_index]
      submitted_app_dates << date
      if status == "approved"
        approved_app_dates << date
      end
    end

    # Submitted apps
    submitted_apps = Hash.new(0)
    submitted_app_dates.each { |d| submitted_apps[d] += 1 }
    sum = 0
    cumulative_submitted_apps = submitted_apps.values.map { |i| sum += i}

    # Approved apps
    approved_apps = Hash.new(0)
    approved_app_dates.each { |d| approved_apps[d] += 1 }
    approved_app_dates = approved_apps.keys
    sum = 0
    cumulative_approved_apps = approved_apps.values.map { |i| sum += i}

    # Chartz!
    data = [
      {
        'name' => '# submitted apps',
        'type' => 'scatter',
        'x' => submitted_app_dates,
        'y' => cumulative_submitted_apps
      },
      {
        'name' => '# approved apps',
        'type' => 'bar',
        'x' => approved_app_dates,
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