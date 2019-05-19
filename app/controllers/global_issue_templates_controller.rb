# noinspection RubocopInspection
class GlobalIssueTemplatesController < ApplicationController
  layout 'base'
  helper :issues
  include IssueTemplatesHelper
  include Concerns::IssueTemplatesCommon
  menu_item :issues
  before_action :find_object, only: %i[show edit update destroy]
  before_action :find_project, only: %i[edit update]
  before_action :require_admin, only: %i[index new show], excep: [:preview]

  #
  # Action for global template : Admin right is required.
  #
  def index
    trackers = Tracker.all
    template_map = {}
    trackers.each do |tracker|
      tracker_id = tracker.id
      templates = GlobalIssueTemplate.search_by_tracker(tracker_id).sorted
      template_map[Tracker.find(tracker_id)] = templates if templates.any?
    end
    render layout: !request.xhr?, locals: { template_map: template_map, trackers: trackers }
  end

  def new
    # create empty instance
    @global_issue_template = GlobalIssueTemplate.new
    render render_form_params
  end

  def create
    @global_issue_template = GlobalIssueTemplate.new(valid_params)
    @global_issue_template.author = User.current
    save_and_flash(:notice_successful_create, :new) && return
  end

  def show
    render render_form_params
  end

  def update
    @global_issue_template.safe_attributes = valid_params
    save_and_flash(:notice_successful_update, :show)
  end

  def edit
    # Change from request.post to request.patch for Rails4.
    return unless request.patch? || request.put?

    @global_issue_template.safe_attributes = valid_params
    save_and_flash(:notice_successful_update, :show)
  end

  def destroy
    unless @global_issue_template.destroy
      flash[:error] = l(:enabled_template_cannot_destroy)
      redirect_to action: :show, id: @global_issue_template
      return
    end

    flash[:notice] = l(:notice_successful_delete)
    redirect_to action: 'index'
  end

  # preview
  def preview
    global_issue_template = params[:global_issue_template]
    id = params[:id]
    @text = (global_issue_template ? global_issue_template[:description] : nil)
    @global_issue_template = GlobalIssueTemplate.find(id) if id
    render partial: 'common/preview'
  end

  private

  def orphaned
    GlobalIssueTemplate.orphaned
  end

  def find_project
    @projects = Project.all
  end

  def find_object
    @global_issue_template = GlobalIssueTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def save_and_flash(message, action_on_failure)
    unless @global_issue_template.save
      render render_form_params.merge(action: action_on_failure)
      return
    end

    respond_to do |format|
      format.html do
        flash[:notice] = l(message)
        redirect_to action: 'show', id: @global_issue_template.id
      end
      format.js { head 200 }
    end
  end

  def template_params
    params.require(:global_issue_template)
          .permit(:title, :tracker_id, :issue_title, :description, :note, :is_default, :enabled,
                  :author_id, :position, project_ids: [], checklists: [])
  end

  def render_form_params
    trackers = Tracker.all
    projects = Project.all
    { layout: !request.xhr?,
      locals: { checklist_enabled: checklist_enabled?, trackers: trackers, apply_all_projects: apply_all_projects?,
                issue_template: @global_issue_template, projects: projects } }
  end
end
