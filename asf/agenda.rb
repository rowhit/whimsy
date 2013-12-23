module ASF
  module Board
  end
end

class ASF::Board::Agenda
  CONTENTS = {
    '2.' => 'Roll Call',
    '3A' => 'Minutes',
    '4A' => 'Executive Officer',
    '1'  => 'Additional Officer',
    'A'  => 'Committee Reports',
    '7A' => 'Special Orders',
    '8.' => 'Discussion Items',
    '9.' => 'Action Items'
  }

  @@parsers = []
  def self.parse(file=nil, &block)
    @@parsers << block if block
    new.parse(file)  if file
  end

  def initialize
    @sections = {}
  end

  def scan(text, pattern, &block)
    text.scan(pattern).each do |matches|
      hash = Hash[pattern.names.zip(matches)]
      yield hash if block

      section = hash.delete('section')
      section ||= hash.delete('attach')

      if section
        hash['approved'] &&= hash['approved'].strip.split(/[ ,]+/)

        @sections[section] ||= {}
        @sections[section].merge!(hash)
      end
    end
  end

  def parse(file)
    @file = file
    @@parsers.each { |parser| instance_exec(&parser) }

    # add index markers for major sections
    CONTENTS.each do |section, index|
      @sections[section][:index] = index if @sections[section]
    end

    # cleanup text and comment whitespace
    @sections.each do |section, hash|
      text = hash['text'] || hash['report']
      if text
        text.sub!(/\A\s*\n/, '')
        text.sub!(/\s+\Z/, '')
        unindent = text.sub(/s+\Z/,'').scan(/^ *\S/).map(&:length).min || 1
        text.gsub! /^ {#{unindent-1}}/, ''
      end

      text = hash['comments']
      if text
        text.sub!(/\A\s*\n/, '')
        text.sub!(/\s+\Z/, '')
        unindent = text.sub(/s+\Z/,'').scan(/^ *\S/).map(&:length).min || 1
        text.gsub! /^ {#{unindent-1}}/, ''
      end
    end

    # add roster and prior report link
    whimsy = 'https://whimsy.apache.org'
    @sections.each do |section, hash|
      next unless section =~ /^(4[A-Z]|\d+|[A-Z][A-Z]?)$/
      title = hash['title']
      title = 'stdcxx' if title == 'C++ Standard Library'
      unless section =~ /^4[A-Z]$/
        hash['roster'] = "#{whimsy}/roster/committee/#{CGI.escape title}"
      end
      hash['prior_reports'] = "#{whimsy}/board/minutes/#{title.gsub(/\W/,'_')}"
    end

    # add attach to section
    @sections.each do |section, hash|
      hash[:attach] = section
    end

    @sections.values
  end
end

require_relative 'agenda/front'
require_relative 'agenda/minutes'
require_relative 'agenda/exec-officer'
require_relative 'agenda/attachments'
require_relative 'agenda/committee'
require_relative 'agenda/special'
require_relative 'agenda/back'