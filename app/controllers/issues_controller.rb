class IssuesController < ApplicationController
  # Prevent error: 'A copy of ApplicationController has been removed
  # from the module tree but is still active!'
  #   http://tinyurl.com/nzu2y2
  unloadable

  before_filter :require_user
  before_filter :set_current_tab, :only => [:index]

  def index
    @issues = get_issues(:page => params[:page])

    respond_to do |format|
      format.html # index.html.haml
      format.xml  { render :xml => @issues }
    end
  end

  def show
    @issue = Issue.find(params[:id])
    @comment = Comment.new

    respond_to do |format|
      format.html # show.html.erb
      format.xml { render :xml => @issue }
    end

  rescue ActiveRecord::RecordNotFound
    respond_to_not_found(:html, :xml)
  end

  def new
    @issue = Issue.new(:user => @current_user)
    @account = Account.new(:user => @current_user)
    @accounts = Account.my(@current_user).all(:order => "name")

    respond_to do |format|
      format.js
      format.xml { render :xml => @issue }
    end
  end

  def edit
    @issue = Issue.find(params[:id])
    # FIXME!
    # The following line throws a TypeError (can't dup NilClass) error.
    # The subsequent line looks stupid, but it works for now.
    @account = @issue.account || Account.new(:user => @current_user)
    @accounts = Account.my(@current_user).all(:order => "name")
    if params[:previous] =~ /(\d+)\z/
      @previous = Issue.find($1)
    end
    respond_to do |format|
      format.js
    end
  rescue ActiveRecord::RecordNotFound
    @previous ||= $1.to_i
    respond_to_not_found(:js) unless @issue
  end

  def update
    @issue = Issue.find(params[:id])
    respond_to do |format|
      if @issue.update_with_account(params)
        # update_sidebar if called_from_index_page?
        format.js
      else
        format.js
      end
    end
  end

  def create
    @issue = Issue.new(params[:issue])

    respond_to do |format|
      # TODO: save_with_account_and_permissions
      if @issue.save_with_account(params)
        # update_sidebar if called_from_index_page?
        format.js
      else
        format.js
      end
    end
  end

  def destroy
    if @issue = Issue.find(params[:id])
      @issue.destroy
      respond_to do |format|
        format.html { respond_to_destroy(:html) }
        format.js   { respond_to_destroy(:ajax) }
        format.xml  { head :ok }
      end
    end
  rescue
    respond_to_not_found(:html, :js, :xml)
  end

  private

  def get_issues(options = { :page => nil, :query => nil })
    self.current_page = options[:page] if options[:page]
    self.current_query = options[:query] if options[:query]

    pages = {
      :page => current_page,
      :per_page => @current_user.pref[:accounts_per_page]  # TODO: create a :issues_per_page preference
    }

    Issue.paginate(pages)
  end

  def respond_to_destroy(method)
    if method == :ajax
      if called_from_index_page?
        @issues = get_issues
        if @issues.blank?
          @issues = get_issues(:page => current_page - 1) if current_page > 1
          render :action => :index and return
        end
      else # called from related asset.
        self.current_page = 1
      end
      # At this point, render destroy.js.rjs
    else
      self.current_page = 1
      flash[:notice] = "#{@issue.name} has been deleted."
      redirect_to(issues_path)
    end
  end
end
