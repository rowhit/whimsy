#
# Landing page
#

_html do
  _title 'ASF Roster'
  _link rel: 'stylesheet', href: 'stylesheets/app.css'

  _banner breadcrumbs: {
    roster: '.'
  }

  _h1_ 'Roster'

  _table.counts do

    ### committers

    _tr do
      _td do
        _a @committers.length, href: 'committer/'
      end

      _td do
        _a 'Committers', href: 'committer/'
      end

      _td 'Search for committers by name, user id, or email address'
    end

    ### members

    _tr do
      _td do
        _a @members.length, href: 'members'
      end

      _td do
        _a 'Members', href: 'members'
      end

      _td 'Active ASF members'
    end

    ### PMCs

    _tr do
      _td do
        _a @committees.length, href: 'committee/'
      end

      _td do
        _a 'PMCs', href: 'committee/'
      end

      _td 'Active projects at the ASF'
    end

    ### Podlings

    _tr do
      _td do
        _a @podlings.select {|podling| podling.status == 'current'}.length,
          href: 'ppmc/'
      end

      _td do
        _a 'Podlings', href: 'ppmc/'
      end

      _td! do 
        _span 'Active podlings at the ASF ('
        _a @podlings.length, href: 'podlings'
        _span ' total)'
      end

    end

    ### Groups

    _tr do
      _td do
        _a @groups.length, href: 'group/'
      end

      _td do
        _a 'Groups', href: 'group/'
      end

      _td 'Assorted other groups from various sources'
    end

  end

  person = ASF::Person.find(env.user)
  if person.asf_member? or ASF.pmc_chairs.include? person
    _hr

    _p do
      _a 'Organization Chart', href: 'orgchart/'
    end
  end
end
