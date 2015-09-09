#!/usr/bin/ruby1.9.1

require 'whimsy/asf'
require 'wunderbar/script'
require 'ruby2js/filter/functions'

# only available to ASF members and PMC chairs
user = ASF::Person.new($USER)
unless user.asf_member? or ASF.pmc_chairs.include? user
  print "Status: 401 Unauthorized\r\n"
  print "WWW-Authenticate: Basic realm=\"ASF Members and Officers\"\r\n\r\n"
  exit
end

_html do
  _style :system if @updates

  _style_ %{
    table {border-collapse: collapse}
    table, th, td {border: 1px solid black}
    td {padding: 3px 6px}
    th {background-color: #a0ddf0}
    tr:hover .diff {background-color: #AAF}

    td[draggable=true] {cursor: move}
    td.modified {background-color: #FF0}
    td.over {background-color: #FFA}

    input[type=text] {width: 100%; box-sizing: border-box}
    input[type=submit] {margin-top: 1em}
  }

  _h1 "public names: LDAP vs ICLA.txt"

  # prefetch LDAP data
  ASF::Person.preload('cn')

  if @updates

    ################################################################## 
    #                         Apply Updates                          #
    ################################################################## 

    _h2_ 'Applying updates'
    updates = JSON.parse(@updates)

    # scope out the work to be done
    svn_updates = []
    ldap_updates = []
    updates.each do |id, names|
      svn_updates << id if names['legal_name'] or names['public_name']
      ldap_updates << id if names['ldap']
    end

    # update SVN
    unless svn_updates.empty?
      officers = '/var/tools/secretary/foundation/officers'
      _.system ['svn', 'cleanup', officers]
      _.system ['svn', 'up', officers]
      iclas = File.read(officers + '/iclas.txt')

      updates.each do |id, names|
        pattern = Regexp.new("^#{Regexp.escape(id)}:(.*?):(.*?):")
        iclas[pattern,1] = names['legal_name']  if names['legal_name']
        iclas[pattern,2] = names['public_name'] if names['public_name']
      end

      File.write(officers + '/iclas.txt', ASF::ICLA.sort(iclas))
      _.system ['svn', 'diff', officers + '/iclas.txt']

      if svn_updates.length > 8
        message = "Update #{svn_updates.length} names"
      else
        message = "Update names for #{svn_updates.sort.join(', ')}"

        if svn_updates.length == 1
          update = updates[svn_updates.first]
          if not update['legal_name']
            message = "Update public name for #{svn_updates.first}"
          elsif not update['public_name']
            message = "Update legal name for #{svn_updates.first}"
          end
        else
          if svn_updates.all? {|update| not update['legal_name']}
            message = "Update public names for #{svn_updates.sort.join(', ')}"
          elsif svn_updates.all? {|update| not update['public_name']}
            message = "Update legal names for #{svn_updates.sort.join(', ')}"
          end
        end
      end

      _.system ['svn', 'commit', '-m', message, 
        ['--no-auth-cache', '--non-interactive'],
        (['--username', $USER, '--password', $PASSWORD] if $PASSWORD),
        officers + '/iclas.txt']
    end

    # update LDAP
    unless ldap_updates.empty?
      ASF::LDAP.bind($USER, $PASSWORD) do
        STDERR.puts 'ldapmodify'
        _pre 'ldapmodify', class: '_stdin'
        updates.each do |id, names|
          next unless names['ldap']
          person = ASF::Person.new(id)
          _pre person.dn, class: '_stdout'
          person.cn = names['ldap']
        end
      end
    end

  else

    ################################################################## 
    #                          Instructions                          #
    ################################################################## 

    _h2_ 'Instructions:'

    _ul do
      _li 'Double click to edit.'
      _li 'Drag/drop to copy.'
      _li 'When done, click "Submit Updates" (at the bottom of the page).'
    end

  end

  #################################################################### 
  #     Show LDAP differences where entry is present in icla.txt     #
  #################################################################### 

  # prefetch ICLA data
  ASF::ICLA.preload

  _h2_!.present! do
    _ 'Present in '
    _a 'icla.txt', 
      href: 'https://svn.apache.org/repos/private/foundation/officers/iclas.txt'
   _ ':'
  end

  _table do
    _tr do
      _th "availid"
      _th "icla.txt real name"
      _th "icla.txt public name"
      _th "LDAP cn"
    end

    ASF::ICLA.new.each do |id, legal_name, name, email|
      next if id == 'notinavail'
      person = ASF::Person.find(id)
      next unless person.dn

      if person.cn != name
        # locate point at which names differ
        first, last = 0, -1
        length = [name.length, person.cn.length].min
        first += 1 while name[first] == person.cn[first]
        last -= 1 while name[last] == person.cn[last] and length >= first-last

        if name[last] == ' ' and name[last] == person.cn[last]
          last -= 1 if (name.length - person.cn.length).abs > 1
        end

        _tr_ do
          _td! do
            _a id, href: "https://whimsy.apache.org/roster/committer/#{id}"
          end
          _td legal_name.gsub(' ', "\u00A0"), draggable: 'true'

          if 
            name[first..last].length > length/2 and 
            person.cn[first..last].length > length/2
          then
            _td name, draggable: 'true'
            _td person.cn, draggable: 'true'
          else
            _td! draggable: 'true' do
              _ name[0...first] unless first == 0
              _span.diff name[first..last].gsub(' ', "\u00A0")
              _ name[last+1..-1] unless last == -1
            end
            _td! draggable: 'true' do
              _ person.cn[0...first] unless first == 0
              _span.diff person.cn[first..last].gsub(' ', "\u00A0")
              _ person.cn[last+1..-1] unless last == -1
            end
          end
        end
      end
    end
  end

  #################################################################### 
  #   Show LDAP differences where entry is NOT present in icla.txt   #
  #################################################################### 

  icla = ASF::ICLA.availids
  ldap = ASF::Person.list.sort_by(&:name)
  ldap.delete ASF::Person.new('apldaptest')

  unless ldap.all? {|person| icla.include? person.id}
    _h2_.missing! 'Only in LDAP'

    _table do
      _tr do
        _th 'id'
        _th 'cn'
        _th 'mail'
      end

      ldap.each do |person|
        next if icla.include? person.id

        _tr_ do
          _td! do
            _a person.id, href:
              "https://whimsy.apache.org/roster/committer/#{person.id}"
          end
          _td person.cn
          _td person.mail.first
        end
      end
    end
  end

  #################################################################### 
  #                   Form used to submit changes                    #
  #################################################################### 

  _form_ method: 'post' do
    _input type: 'hidden', name: 'updates'
    _input type: 'submit', value: 'Commit Changes', disabled: true
  end

  #################################################################### 
  #                        Client side logic                         #
  #################################################################### 

  _script do
    # track current drag operation
    row = nil
    dragText = nil

    # enable submit button only when there is modifications
    def enable_submit()
      button = document.querySelector('input[type=submit]')
      modified = document.querySelectorAll('td.modified')

      button.disabled = (modified.length == 0)
    end

    # add drag/drop, mouse click event handlers to cells marked as draggable
    Array(document.getElementsByTagName('td')).each do |td|
      next unless td.getAttribute('draggable') == 'true'

      # dragstart: capture row and textContent
      td.addEventListener(:dragstart) do |event|
        row = event.target.parentNode
        dragText = this.textContent
        event.dataTransfer.setData('text/plain', dragText)
      end

      # dragover: add CSS class 'over' if same row and text is different
      td.addEventListener(:dragover) do |event|
        return unless row == event.target.parentNode
        if event.target.textContent != dragText
          event.target.classList.add 'over'
          event.preventDefault() 
        end
      end

      # dragleave: remove CSS class 'over'
      td.addEventListener(:dragleave) do |event|
        event.currentTarget.classList.remove 'over'
      end

      # drop: update text after capturing original text
      td.addEventListener(:drop) do |event|
        data = event.dataTransfer.getData('text/plain')
        event.target.classList.remove 'over'

        if not event.target.getAttribute('data-original')
          event.target.setAttribute('data-original', event.target.textContent)
          event.target.classList.add 'modified'
        elsif data == event.target.getAttribute('data-original')
          event.target.removeAttribute('data-original')
          event.target.classList.remove 'modified'
        else
          event.target.classList.add 'modified'
        end

        event.target.textContent = data
        event.preventDefault()
        enable_submit()
        row = nil
      end

      # mouseup: replace cell with an input field
      td.addEventListener(:dblclick) do |event|
        input = document.createElement('input')
        input.setAttribute('type', 'text')
        input.value = event.target.textContent

        if not event.target.getAttribute('data-original')
          event.target.setAttribute('data-original', input.value)
        end

        event.target.firstChild.remove() while event.target.firstChild
        event.target.appendChild(input)
        event.target.setAttribute('draggable', 'false')
        input.focus()

        # when focus leaves input, replace cell with modified text
        input.addEventListener(:blur) do |event|
          parent = input.parentNode
          value = input.value
          input.remove()
          parent.textContent = value
          parent.setAttribute('draggable', 'true')

          if value == parent.getAttribute('data-original')
            parent.removeAttribute('data-original')
            parent.classList.remove 'modified'
          else
            parent.classList.add 'modified'
          end

          enable_submit()
        end
      end
    end

    # capture modifications when button is pressed
    document.querySelector('input[type=submit]').addEventListener(:click) do
      updates = {}
      columnNames = %w(id legal_name public_name ldap)

      Array(document.querySelectorAll('td.modified')).each do |td|
        id = td.parentNode.firstElementChild.textContent.strip()
        updates[id] ||= {}
        updates[id][columnNames[td.cellIndex]] = td.textContent
      end

      document.querySelector('form input').value = JSON.stringify(updates)
    end

    # force submit state on initial load (i.e., disable submit button)
    enable_submit()
  end
end