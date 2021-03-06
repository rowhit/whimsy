#
# Display information associated with an agenda item:
#   - special notes
#   - minutes
#   - posted reports
#   - action items
#   - posted comments
#   - pending comments
#   - historical comments
#
# Note: if AdditionalInfo is included multiple times in a page, set
#       prefix to true (or a string) to ensure rendered id attributes
#       are unique.
#

class AdditionalInfo < React
  def render
    # special notes
    _p.notes @@item.notes if @@item.notes

    # minutes
    minutes = Minutes.get(@@item.title)
    if minutes
      _h4 'Minutes', id: "#{@prefix}minutes"
      _pre.comment minutes
    end

    # posted reports
    if @@item.missing
      posted = Posted.get(@@item.title)
      unless posted.empty?
        _h4 'Posted reports', id: "#{@prefix}posted"
        _ul posted do |post|
          _li do
            _a post.subject, href: post.link
          end
        end
      end
    end

    # action items
    if @@item.title != 'Action Items' and not @@item.actions.empty?
      _h4 id: "#{@prefix}actions" do
        _Link text: 'Action Items', href: 'Action-Items'
      end
      _ActionItems item: @@item, filter: {pmc: @@item.title}
    end

    unless @@item.special_orders.empty?
      _h4 'Special Orders', id: "#{@prefix}orders"
      _ul do
        @@item.special_orders.each do |resolution|
          _li do
            _Link text: resolution.title, href: resolution.href
          end
        end
      end
    end

    # posted comments
    history = HistoricalComments.find(@@item.title)
    if not @@item.comments.empty? or (history and not @prefix)
      _h4 'Comments', id: "#{@prefix}comments"
      @@item.comments.each do |comment|
        _pre.comment do
          _Text raw: comment, filters: [hotlink]
        end
      end

      # pending comments
      if @@item.pending
        _h5 'Pending Comment', id: "#{@prefix}pending"
        _pre.comment Flow.comment(@@item.pending, Pending.initials)
      end

      # historical comments
      if history and not @prefix
        for date in history
          next if Agenda.file == "board_agenda_#{date}.txt"

          _h5.history do
            _span "\u2022 "
            _a date.gsub('_', '-'),
              href: HistoricalComments.link(date, @@item.title)
            _span ': '

            # link to mail archive for feedback thread
            if date > '2016_04' # when feedback emails were first started
              # compute date range: from date of that meeting to now
              dfr = date.gsub('_', '-')
              dto = Date.new(Date.now()).toISOString()[0...10]

              _a '(thread)', 
                href: 'https://lists.apache.org/list.html?board@apache.org&' +
                  "d=dfr=#{dfr}|dto=#{dto}&header_subject=" +
                  "'Board%20feedback%20on%20#{dfr}%20#{@@item.title}%20report'"
            end
          end

          splitComments(history[date]).each do |comment|
            _pre.comment do
              _Text raw: comment, filters: [hotlink]
            end
          end
        end
      end
    else
      # pending comments
      if @@item.pending
        _h4 'Pending Comment', id: "#{@prefix}pending"
        _pre.comment Flow.comment(@@item.pending, Pending.initials)
      end
    end
  end

  # ensure componentWillReceiveProps is called on before first rendering
  def componentWillMount()
    self.componentWillReceiveProps()
  end

  # determine prefix (if any)
  def componentWillReceiveProps()
    if @@prefix == true
      @prefix = @@item.title.downcase() + '-'
    elsif @@prefix
      @prefix = @@prefix
    else
      @prefix = ''
    end
  end
end
