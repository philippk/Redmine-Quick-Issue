class QuickIssuesController < ApplicationController
  unloadable
  before_filter :find_project, :only => [:new, :create]
  before_filter :check_for_default_issue_status, :only => [:new, :create]
  before_filter :build_new_issue_from_params, :only => [:new, :create]
  verify :method => :post, :only => :create, :render => {:nothing => true, :status => :method_not_allowed }
  
  def create
    call_hook(:controller_issues_new_before_save, { :params => params, :issue => @issue })
    if @issue.save
      flash[:notice] = "Issue \##{@issue.id} created (#{@issue.subject})."
      redirect_to '/my/page'
    else
      flash[:error] = "The issue has not been saved."
      redirect_to '/my/page'
    end
  end
  
  def find_project
    assigned_to_id = (params[:issue] && params[:issue][:assigned_to_id]) || params[:assigned_to_id]
    user = User.find(assigned_to_id)
    unless @project = Project.find_by_identifier(user.login)
      flash[:error] = "No project found for user #{user.login}."
      redirect_to '/my/page'
    end
  end
  
  def build_new_issue_from_params
    if params[:id].blank?
      @issue = Issue.new
      @issue.copy_from(params[:copy_from]) if params[:copy_from]
      @issue.project = @project
    else
      @issue = @project.issues.visible.find(params[:id])
    end

    @issue.project = @project
    @issue.author = User.current
    # Tracker must be set before custom field values
    @issue.tracker ||= @project.trackers.find((params[:issue] && params[:issue][:tracker_id]) || params[:tracker_id] || :first)
    if @issue.tracker.nil?
      render_error l(:error_no_tracker_in_project)
      return false
    end
    @issue.start_date ||= Date.today
    if params[:issue].is_a?(Hash)
      @issue.safe_attributes = params[:issue]
      if User.current.allowed_to?(:add_issue_watchers, @project) && @issue.new_record?
        @issue.watcher_user_ids = params[:issue]['watcher_user_ids']
      end
    end
    @priorities = IssuePriority.active
    @allowed_statuses = @issue.new_statuses_allowed_to(User.current, true)
  end
  
  def check_for_default_issue_status
    if IssueStatus.default.nil?
      render_error l(:error_no_default_issue_status)
      return false
    end
  end
  
end