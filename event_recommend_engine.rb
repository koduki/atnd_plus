require 'atnd4r'

class EventRecommendEngine
  def initialize
  end

  def get_my_joined_events my_user_id
    Atnd4r.get_event_list({:user_id => my_user_id}).events
  end

  def get_similar_users events, my_user_id
    users = events.map{|e|
      Atnd4r.get_user_list({:event_id => e.event_id})
            .events.first.users
            .map{|u| {nickname:u.nickname, user_id:u.user_id, event_id:e.event_id} }
    }.flatten

    users.group_by{|u| u[:user_id]}
         .map{|u| 
              join_events = u[1].map{|x| x[:event_id] } 
              {user_id:u[0], nickname:u[1][0][:nickname], join_event:join_events}
         }.delete_if{|user| user[:user_id] == my_user_id }
  end

  def get_users_dist users, my_user_id, ym_range
    my_join_events = Atnd4r.get_event_list({user_id:my_user_id, ym:ym_range})
                           .events
                           .map{|e| e.event_id }

    users.map do |user|
      dist = user[:join_event].reduce(0) do |r, x| 
        r + ((my_join_events.index(x) != nil) ? 1 : 0) 
      end
      user.merge({dist:dist})
    end
  end

  def get_events_dist users_dist, ym_range
    users_dist.map{|user|
      events = Atnd4r.get_event_list({user_id:user[:user_id], ym:ym_range}).events
      events.map{|e| {event:e, dist:user[:dist]} }
    }.flatten.group_by{|e| e[:event].event_id }
  end

  def get_event_ranking events_dist
    event_ranking = events_dist.map do |e|
      score = e[1].reduce(0){|r, x| r + x[:dist]}
      [e[1].first[:event], score] 
    end
    event_ranking.sort{|x, y| y[1] <=> x[1] }
  end

  def get_current_ranking my_user_id, ym_range, current_time
    joined_events =  get_my_joined_events my_user_id

    similar_users = get_similar_users joined_events, my_user_id 
    users_dist = get_users_dist similar_users, my_user_id, ym_range

    events_dist = get_events_dist users_dist, ym_range
    event_ranking = get_event_ranking events_dist

    event_ranking.select{|event| event.first.started_at > current_time}
  end
end
