require 'mechanize'

class SC2Stats

  def calc_all_leagues
    ['master', 'diamond', 'platinum', 'gold', 'silver', 'bronze'].each { |league|
      calc_league league
      puts '----------------'
    }
  end

  def calc_league league
    hundreds_counter = 0
    sc2ranks_rooturl = "http://www.sc2ranks.com/ranks/all/#{league}/1/all/points/"

    sc2_players = []
    num_pages = 0

    agent = Mechanize.new { |agent| agent.user_agent_alias = 'Mac Safari' } 

    # Read the number of pages
    agent.get(sc2ranks_rooturl) do |page|
      num_pages_text = page.search(".//div[@class='paginate-top']/div[@class='page']").first.content

      # Discard the text part (i.e. 'Page <input> of 1,443' -> 1443)
      num_pages = /\d+/.match(num_pages_text.gsub(',', '')).to_s.to_i
    end

    puts "Number of pages for " + league + " league: " + num_pages.to_s

    num_pages.times do
      # We need to shutdown the Net:HTTP:Persistent if we don't want to get a 'closed stream' exception
      agent.http.shutdown

      current_url = "http://www.sc2ranks.com/ranks/all/#{league}/1/all/points/#{hundreds_counter}"
      print "\rReading page " + current_url
      begin
        agent.get(current_url) do |page|
          append_players_for_page page, sc2_players
        end
      rescue
        # It should never happen...
        puts 'Exception while loading page ' + current_url
      end
      hundreds_counter += 100
    end

    puts "\n\nTotal players in " + league + " league: " + sc2_players.count.to_s

    [ 'zerg', 'protoss', 'terran' ].each do |race|
      puts "\n" + race + " stats:"
      total_num_matches = 0
      total_num_players = sc2_players.count { |player|
        b_ret = false
        if player.race == race
          total_num_matches += player.total_num_matches
          b_ret = true
        end        
        b_ret
      }
      puts "\tTotal players: " + total_num_players.to_s
      puts "\tTotal matches: " + total_num_matches.to_s
      puts "\tAverage matches per player: " + (total_num_matches / total_num_players).to_s
    end

    agent.http.shutdown
  end

  def append_players_for_page(page, players_array)
    # http://mechanize.rubyforge.org/mechanize/EXAMPLES_rdoc.html
    # http://nokogiri.org/tutorials

    # The table we are looking for has id='sortlist'
    the_table = page.search(".//table[@id='sortlist']")

    the_trs = the_table.search("tr")

    # The first <tr> is just the header that displays the column info
    the_trs = the_trs[1..the_trs.count]

    the_trs.each do |single_tr|
      race_tr = single_tr.search(".//td[contains(@class, 'character')]/img").first

      # Sometimes the race is not defined, probably because a bug in sc2ranks.com
      next if race_tr == nil
      
      race = race_tr['class']
      num_wins = single_tr.search(".//td[contains(@class, 'wins')]").first.content
      num_losses = single_tr.search(".//td[contains(@class, 'losses')]").first.content

      the_sc2_player = SC2Player.new(num_wins, num_losses, race)

      players_array.push(the_sc2_player)
    end
  end
  
end

class SC2Player

  attr_reader :race
  attr_reader :num_wins
  attr_reader :num_losses

  def initialize num_wins, num_losses, race
    @num_wins = num_wins.gsub(',', '').to_i
    @num_losses = num_losses.gsub(',', '').to_i
    @race = race
  end

  def total_num_matches
    @num_wins + @num_losses
  end

end