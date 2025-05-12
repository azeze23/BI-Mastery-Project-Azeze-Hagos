WITH 
joined_tables AS (
  SELECT 
    s.user_id AS u_id,
    s.session_id,
    s.trip_id AS s_trip_id,
    s.cancellation,
    s.flight_discount_amount,
    s.hotel_discount_amount,
    s.flight_booked,
    s.hotel_booked,
    u.has_children,
    h.nights,
    h.rooms,
    h.check_in_time,
    h.check_out_time,
    h.hotel_per_room_usd,
    f.checked_bags,
    f.base_fare_usd,
    -- Calculated columns
    CASE
      WHEN h.check_out_time::date - h.check_in_time::date < 1 
        THEN 1 
        ELSE h.check_out_time::date - h.check_in_time::date 
    END AS nights_new,
    CASE 
      WHEN h.rooms = 0 THEN 1 
      ELSE h.rooms 
    END AS new_rooms
  FROM sessions s
  LEFT JOIN users u ON s.user_id = u.user_id
  LEFT JOIN hotels h ON s.trip_id = h.trip_id
  LEFT JOIN flights f ON s.trip_id = f.trip_id
  WHERE s.session_start >= '2023-01-04'
),

user_level AS (
  SELECT
    u_id AS ul_id
  FROM joined_tables
  GROUP BY u_id
  HAVING COUNT(session_id) > 7
),

user_metrics AS (
  SELECT 
    jt.u_id,
    COUNT(DISTINCT jt.s_trip_id) AS total_trips,
    AVG(jt.nights_new) AS avg_stay_length,
    AVG(jt.checked_bags) AS avg_checked_bags,
    COUNT(*) FILTER (WHERE jt.cancellation = true) * 1.0 / COUNT(*) AS cancellation_rate,
    SUM(jt.base_fare_usd + jt.hotel_per_room_usd * jt.new_rooms * jt.nights_new) AS total_spend,
    AVG(jt.flight_discount_amount) AS avg_flight_discount_used,
    AVG(jt.hotel_discount_amount) AS avg_hotel_discount_used,
    COUNT(*) FILTER (WHERE jt.flight_booked OR jt.hotel_booked) * 1.0 / COUNT(*) AS booking_rate,
    MAX(CASE WHEN jt.has_children THEN 1 ELSE 0 END) AS child_flag
  FROM joined_tables jt
  JOIN user_level ul ON jt.u_id = ul.ul_id
  GROUP BY jt.u_id
)

SELECT * FROM user_metrics;
