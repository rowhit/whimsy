require 'whimsy/asf/agenda'
require 'date'
require 'json'

class HistoricalComments
  @@mtime = nil
  @@comments = nil

  def self.comments
    # look for agendas in the last year + half a month
    cutoff = (Date.today - 380).strftime('board_agenda_%Y_%m_%d')

    # select and sort agendas for meetings past the cutoff
    agendas = Dir["#{ASF::SVN['private/foundation/board']}/**/board_agenda_*"].
      select {|file| File.basename(file) > cutoff}.
      sort_by {|file| File.basename(file)}.
      map {|file| file.untaint}

    # drop latest agenda
    agendas.pop

    # return previous results unless an agenda has been updated
    mtime = agendas.map {|file| File.mtime(file)}.max
    return @@comments if mtime == @@mtime

    # initialize comments to empty hash of hashes
    comments = Hash.new {|hash, key| hash[key] = {}}

    # gather up titles and comments
    agendas.reverse.each do |agenda|
      date = agenda[/\d+_\d+_\d+/]
      ASF::Board::Agenda.parse(File.read(agenda), true).each do |report|
        next if report['comments'].to_s.empty?
        comments[report['title']][date] = report['comments']
      end
    end

    # cache and return results
    @@mtime = mtime
    @@comments = comments
  end
end
