#
# Post or edit a report or resolution
#

class Post < React
  def initialize
    @disabled = false
  end

  # default attributes for the button associated with this form
  def self.button
    {
      text: 'post report',
      class: 'btn_primary',
      data_toggle: 'modal',
      data_target: '#post-report-form'
    }
  end

  def render
    # determine if reflow button should be default or danger color
    width = 80 - @indent.length
    if @report.split("\n").all? {|line| line.length <= width}
      reflow_class = 'btn-default'
    else
      reflow_class = 'btn-danger'
    end

    _ModalDialog.wide_form.post_report_form! color: 'commented' do
      _h4 @title

      #input field: report text
      _textarea.post_report_text! label: @label, value: @report,
        placeholder: @label, rows: 17, disabled: @disabled, 
        onChange: self.change

      #input field: commit_message
      _input.post_report_message! label: 'commit message', disabled: @disabled,
        defaultValue: @message

      # footer buttons
      _button.btn_default 'Cancel', data_dismiss: 'modal', disabled: @disabled
      _button 'Reflow', class: reflow_class, onClick: self.reflow
      _button.btn_primary 'Submit', onClick: self.submit, disabled: @disabled
    end
  end

  # set properties on initial load
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # autofocus on report/resolution text
  def componentDidMount()
    jQuery('#post-report-form').on 'shown.bs.modal' do
      ~'#post-report-text'.focus()
    end
  end

  # match form title, input label, and commit message with button text
  def componentWillReceiveProps()
    case @@button.text
    when 'post report'
      @title = 'Post Report'
      @label = 'report'
      @message = "Post #{@@item.title} Report"
    when 'edit report'
      @title = 'Edit Report'
      @label = 'report'
      @message = "Edit #{@@item.title} Report"
    when 'edit resolution'
      @title = 'Edit Resolution'
      @label = 'resolution'
      @message = "Edit #{@@item.title} Resolution"
    end

    @indent = (@@item.attach =~ /^4/ ? '        ' : '')
    @report = @@item.text
  end

  # track changes to input value; change color of reflow button when
  # there is a need for a reflow.
  def change(event)
    @report = event.target.value
  end

  # reflow
  def reflow()
    @report = Flow.text(@report, @indent)
  end

  # when save button is pushed, post comment and dismiss modal when complete
  def submit(event)
    data = {
      agenda: Agenda.file,
      attach: @@item.attach,
      digest: @@item.digest,
      message: ~'#post-report-message'.value,
      report: ~'#post-report-text'.value
    }

    @disabled = true
    post 'post', data do |response|
      jQuery('#post-report-form').modal(:hide)
      @disabled = false
      Agenda.load response.agenda
    end
  end
end
