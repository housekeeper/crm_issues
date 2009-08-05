require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe IssuesController do

  before(:each) do
    require_user
    set_current_tab(:issues)
  end

  # GET /issues
  # GET /issues.xml
  #----------------------------------------------------------------------------
  describe "responding to GET index" do

    before(:each) do
      #get_data_for_sidebar
    end

    it "should expose all issues as @issues and render [index] template" do
      @issues = [ Factory(:issue, :user => @current_user) ]

      get :index
      assigns[:issues].should == @issues
      response.should render_template("issues/index")
    end

    it "should expose the data for the issues sidebar"

    it "should filter out issues by priority"

    describe "AJAX pagination" do
      it "should pick up page number from params" do
        @issues = [ Factory(:issue, :user => @current_user) ]
        xhr :get, :index, :page => 42

        assigns[:current_page].to_i.should == 42
        assigns[:issues].should == [] # page #42 should be empty
        session[:issues_current_page].to_i.should == 42
        response.should render_template("issues/index")
      end

      it "should pick up saved page number from session" do
        session[:issues_current_page] = 42
        @issues = [ Factory(:issue, :user => @current_user) ]
        xhr :get, :index

        assigns[:current_page].to_i.should == 42
        assigns[:issues].should == [] # page #42 should be empty
        response.should render_template("issues/index")
      end
    end

    describe "with mime type of XML" do
      it "should render all issues as xml" do
        request.env["HTTP_ACCEPT"] = "application/xml"
        @issues = [ Factory(:issue, :user => @current_user) ]

        get :index
        response.body.should == @issues.to_xml
      end
    end
  end

  # GET /issues/1
  # GET /issues/1.xml                                               HTML
  #----------------------------------------------------------------------------
  describe "responding to GET show" do
    describe "with mime type of HTML" do
      before(:each) do
        @issue = Factory(:issue, :id => 42)
        @comment = Comment.new
      end

      it "should expose the requested issue as @issue and render the [show] template" do
        get :show, :id => 42
        assigns[:issue].should == @issue
        assigns[:comment].attributes.should == @comment.attributes
        response.should render_template("issues/show")
      end

      it "should update an activity when viewing the issue" # do
        #Activity.should_receive(:log).with(@current_user, @issue, :viewed).once
        #get :show, :id => @issue.id
      #end
    end

    describe "with the mime type of XML" do
      it "should render the requested issue as XML" do
        @issue = Factory(:issue, :id => 42)

        request.env["HTTP_ACCEPT"] = "application/xml"
        get :show, :id => 42
        response.body.should == @issue.to_xml
      end
    end

    describe "issue got deleted or otherwise unavailable" do
      it "should redirect to issues index if the issue got deleted" do
        @issue = Factory(:issue, :user => @current_user).destroy

        get :show, :id => @issue.id
        flash[:warning].should_not == nil
        response.should redirect_to(issues_path)
      end

      it "should redirect to issues index if the issue is protected" do
        @private = Factory(:issue, :user => Factory(:user), :access => "Private")

        get :show, :id => @private.id
        flash[:warning].should_not == nil
        response.should redirect_to(issues_path)
      end

      it "should return 404 (not found) XML error" do
        @issue = Factory(:issue, :user => @current_user).destroy
        request.env["HTTP_ACCEPT"] = "application/xml"

        get :show, :id => @issue.id
        response.code.should == "404" # :not_found
      end
    end
  end

  # GET /issues/new
  # GET /issues/new.xml                                             AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET new" do
    it "should expose a new issue as @issue and render [new] template" do
      @issue = Issue.new(:user => @current_user, :access => "Private")
      @account = Account.new(:user => @current_user, :access => "Private")
      @users = [ Factory(:user) ]
      @accounts = [ Factory(:account, :user => @current_user) ]

      xhr :get, :new
      assigns[:issue].attributes.should == @issue.attributes
      assigns[:account].attributes.should == @account.attributes
      assigns[:users].should == @users
      assigns[:accounts].should == @accounts
      response.should render_template("issues/new")
    end

    it "should create an instance of related object when necessary" do
      @account = Factory(:account, :id => 42)

      xhr :get, :new, :related => "account_42"
      assigns[:account].should == @account
    end

    describe "(when creating related issue)" do
      it "should redirect to parent asset's index page with the message if parent asset got deleted" do
        @account = Factory(:account).destroy

        xhr :get, :new, :related => "account_#{@account.id}"
        flash[:warning].should_not == nil
        response.body.should == 'window.location.href = "/accounts";'
      end

      it "should redirect to parent asset's index page with the message if parent asset got protected" do
        @account = Factory(:account, :access => "Private")
        
        xhr :get, :new, :related => "account_#{@account.id}"
        flash[:warning].should_not == nil
        response.body.should == 'window.location.href = "/accounts";'
      end
    end
  end

  # GET /issues/1/edit                                              AJAX
  #----------------------------------------------------------------------------
  describe "responding to GET edit" do
    it "should expose the requested issue as @issue and render [edit] template" do
      @issue = Factory(:issue, :user => @current_user, :id => 42)
      @account = Account.new(:user => @current_user)
      @users = [ Factory(:user) ]
      @accounts = [ Factory(:account, :user => @current_user) ]

      xhr :get, :edit, :id => 42
      assigns[:issue].should == @issue
      assigns[:account].attributes.should == @account.attributes
      assigns[:accounts].should == @accounts
      assigns[:users].should == @users
      assigns[:previous].should == nil
      response.should render_template("issues/edit")
    end

    it "should expose previous issue as @previous when necessary" do
      @issue = Factory(:issue, :id => 42)
      @previous = Factory(:issue, :id => 41)

      xhr :get, :edit, :id => 42, :previous => 41
      assigns[:previous].should == @previous
    end

    describe "issue got deleted or is otherwise unavailable" do
      it "should reload current page with the flash message if the issue got deleted" do
        @issue = Factory(:issue, :user => @current_user).destroy

        xhr :get, :edit, :id => @issue.id
        flash[:warning].should_not == nil
        response.body.should == "window.location.reload();"
      end

      it "should reload current page with the flash message if the issue is protected" do
        @private = Factory(:issue, :user => Factory(:user), :access => "Private")

        xhr :get, :edit, :id => @private.id
        response.body.should == "window.location.reload();"
      end
    end

    describe "(previous issue got deleted or is otherwise unavailable)" do
      before(:each) do
        @issue = Factory(:issue, :user => @current_user)
        @previous = Factory(:issue, :user => Factory(:user))
      end

      it "should notivy the veiw if previuos issue got deleted" do
        @previous.destroy

        xhr :get, :edit, :id => @issue.id, :previous => @previous.id
        flash[:warning].should == nil  # no warning, just silently remove the div
        assigns[:previous].should == @previous.id
        response.should render_template("issues/edit")
      end

      it "should notify the view if previous issue got protected" do
        @previous.update_attribute(:access, "Private")

        xhr :get, :edit, :id => @issue.id, :previous => @previous.id
        flash[:warning].should == nil  # no warning, just silently remove the div
        assigns[:previous].should == @previous.id
        response.should render_template("issues/edit")
      end
    end
  end

  # POST /issues
  # POST /issues.xml                                                AJAX
  #----------------------------------------------------------------------------
  describe "responding to POST create" do
    describe "with valid params" do

      before(:each) do
        @issue = Factory.build(:issue, :user => @current_user)
        Issue.stub!(:new).and_return(@issue)
      end

      it "should expose a newly created issue as @issue and render [create] template" do
        xhr :post, :create, :issue => { :summary => "Nothing works"}, :account => { :name => "My account" }, :users => %w(1 2 3)
        assigns(:issue).should == @issue
        response.should render_template("issues/create")
      end

      it "should get sidebar data if called from issues index" 

      it "should reload issues to update pagination if called from issues index" do
        request.env["HTTP_REFERER"] = "http://localhost/issues"

        xhr :post, :create, :issue => { :summary => "Nothing works" }, :account => { :name => "My account" }, :users => %w(1 2 3)
        assigns[:issues].should == [ @issue ]
      end
      
      it "should create new account and associate it with the issue" do
        xhr :post, :create, :issue => { :name => "Nothing works" }, :account => { :name => "new account" }
        assigns(:issue).should == @issue
        @issue.account.name.should == "new account"
      end

      it "should associate issue with the existing account" do
        @account = Factory(:account, :id => 42)

        xhr :post, :create, :issue => { :name => "Nothing works" }, :account => { :id => 42 }, :users => []
        assigns(:issue).should == @issue
        @issue.account.should == @account
        @account.issues.should include(@issue)
      end

    end
    
    describe "with invalid params" do
      it "should expose a newly created but unsaved issue as @issue with blank @account and render [create] template" do
        @issue = Factory.build(:issue, :summary => nil, :user => @current_user)
        Issue.stub!(:new).and_return(@issue)
        @users = [ Factory(:user) ]
        @account = Account.new(:user => @current_user)
        @accounts = [ Factory(:account, :user => @current_user) ]

        # Expect to redraw [create] form with blank account.
        xhr :post, :create, :issue => {}, :account => { :user_id => @current_user.id }
        assigns(:issue).should == @issue
        assigns(:users).should == @users
        assigns(:account).attributes.should == @account.attributes
        assigns(:accounts).should == @accounts
        response.should render_template("issues/create")
      end

      it "should expose a newly created but unsaved issue as @issue with existing @account and render [create] template" do
        @account = Factory(:account, :id => 42, :user => @current_user)
        @issue = Factory.build(:issue, :summary => nil, :user => @current_user)
        Issue.stub!(:new).and_return(@issue)
        @users = [ Factory(:user) ]

        # Expect to redraw [create] form with selected account.
        xhr :post, :create, :issue => {}, :account => { :id => 42, :user_id => @current_user.id }
        assigns(:issue).should == @issue
        assigns(:users).should == @users
        assigns(:account).should == @account
        assigns(:accounts).should == [ @account ]
        response.should render_template("issues/create")
      end
    end

  end
  
  # PUT /issue/1
  # PUT /issue/1.xml                                               AJAX
  #----------------------------------------------------------------------------
  describe "responding to PUT udpate" do

    describe "with valid params" do

      it "should update the requested issue, expose it as @issue, and render [update] template" do
        @issue = Factory(:issue, :id => 42)

        xhr :put, :update, :id => 42, :issue => { :summary => "Its broken!" }, :account => { :name => "My account" }, :users => %w(1 2 3)
        @issue.reload.summary.should == "Its broken!"
        assigns(:issue).should == @issue
        response.should render_template("issues/update")
      end

      it "should get sidebar data if called from issues index"

      it "should be able to create an account and associate it with updated issue" do
        @issue = Factory(:issue, :id => 42)

        xhr :put, :update, :id => 42, :issue => { :summary => "Fixed it" }, :account => { :name => "new account" }
        assigns[:issue].should == @issue
        @issue.account.should_not be_nil
        @issue.account.name.should == "new account"
      end

      it "should be able to assign a different account to the updated issue" do
        @old_account = Factory(:account, :id => 111)
        @new_account = Factory(:account, :id => 999)
        @issue = Factory(:issue, :id => 42)
        Factory(:account_issue, :account => @old_account, :issue => @issue)

        xhr :put, :update, :id => 42, :issue => { :summary => "Hello" }, :account => { :id => 999 }
        assigns[:issue].should == @issue
        @issue.account.should == @new_account
      end

      it "should update issue permissions when sharing with specific users" do
        @issue = Factory(:issue, :id => 42, :access => "Public")
        he  = Factory(:user, :id => 7)
        she = Factory(:user, :id => 8)

        xhr :put, :update, :id => 42, :issue => { :summary => "See this", :access => "Shared" }, :users => %w(7 8), :account => {}
        @issue.reload.access.should == "Shared"
        @issue.permissions.map(&:user_id).sort.should == [ 7, 8 ]
        assigns[:issue].should == @issue
      end

      describe "issue got deleted or otherwise unavailable" do
        it "should reload current page with the flash message if teh issue got deleted" do
          @issue = Factory(:issue, :user => @current_user).destroy

          xhr :put, :update, :id => @issue.id
          flash[:warning].should_not == nil
          response.body.should == "window.location.reload();"
        end

        it "should reload current page with the flash message if the issue is protected" do
          @private = Factory(:issue, :user => Factory(:user), :access => "Private")

          xhr :put, :update, :id => @private.id
          flash[:warning].should_not == nil
          response.body.should == "window.location.reload();"
        end
      end

    end
  end
end
