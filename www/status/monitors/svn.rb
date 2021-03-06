#
# Monitor status of svn updates
#
=begin
Sample input:
---- cut here ---

/srv/svn/Bills
Updating '.':
At revision 67610.

/srv/svn/Meetings
Updating '.':
At revision 67610.

---- cut here ---

Output status level can be:
Success - workspace is up to date
Info - one or more files updated
Warning - partial response
Danger - unexpected text in log file

=end

def Monitor.svn(previous_status)
  # read cron log
  log = File.expand_path('../../../logs/svn-update', __FILE__)
  data = File.open(log) {|file| file.flock(File::LOCK_EX); file.read}
  updates = data.split(%r{\n(?:/\w+)*/srv/svn/})[1..-1]

  status = {}

  # extract status for each repository
  updates.each do |update|
    level = 'success'
    title = nil
    data = revision = update[/^(Updated to|At) revision \d+\.$/]

    lines = update.split("\n")
    repository = lines.shift.to_sym

    lines.reject! do |line| 
      line == "Updating '.':" or
      line =~ /^(Checked out|Updated to|At) revision \d+\.$/
    end

    unless lines.empty?
      level = 'info'
      data = lines.dup
    end

    lines.reject! {|line| line =~ /^([ADU] |[ U]U)   /}

    if lines.empty?
      if not data
        title = "partial response"
        level = 'warning'
      # data may be a String rather than an array in which case .length is its length, not 1
      elsif String  === data or data.length == 1
        title = "1 file updated"
      else
        title = "#{data.length} files updated"
      end

      data << revision if revision and data.instance_of? Array
    else
      level = 'danger'
      data = lines.dup
    end

    status[repository] = {level: level, data: data, href: '../logs/svn-update'}
    status[repository][:title] = title if title
  end

  {data: status}
end

# for debugging purposes
if __FILE__ == $0
  require_relative 'unit_test'
  runtest('svn') # must agree with method name above
end
