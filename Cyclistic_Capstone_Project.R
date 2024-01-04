library(tidyverse)
library(lubridate)
library(readr)

q1_2019 <- read_csv("raw_data/Divvy_Trips_2019_Q1.csv")
q2_2019 <- read_csv("raw_data/Divvy_Trips_2019_Q2.csv")
q3_2019 <- read_csv("raw_data/Divvy_Trips_2019_Q3.csv")
q4_2019 <- read_csv("raw_data/Divvy_Trips_2019_Q4.csv")

colnames(q1_2019)
colnames(q2_2019)
colnames(q3_2019)
colnames(q4_2019)

# q1_2019, q3_2019, q4_2019 all have the same column names and column data types, but the column names for q2_2019 are different. So we will have to rename the column names for q2_2019 so that they are identical to those for the other three dataframes, and then we can combine the four dataframes into a single dataframe for the year 2019.

# Rename the columns for q2_2019

q2_2019 <- rename(q2_2019,
  trip_id = "01 - Rental Details Rental ID",
  start_time = "01 - Rental Details Local Start Time",
  end_time = "01 - Rental Details Local End Time",
  bikeid = "01 - Rental Details Bike ID",
  tripduration = "01 - Rental Details Duration In Seconds Uncapped",
  from_station_id = "03 - Rental Start Station ID",
  from_station_name = "03 - Rental Start Station Name",
  to_station_id = "02 - Rental End Station ID",
  to_station_name = "02 - Rental End Station Name",
  usertype = "User Type",
  gender = "Member Gender",
  birthyear = "05 - Member Details Member Birthday Year"
)

# Now we'll check that the new column names for q2_2019 match the column names for one of the other dataframes.

colnames(q1_2019)
colnames(q2_2019)

# Next, we will inspect the structures of the dataframes and make sure that they have the same column names and datatypes.

glimpse(q1_2019)
glimpse(q2_2019)
glimpse(q3_2019)
glimpse(q4_2019)

# Now we combine the dataframes for the four quarters of 2019 into a single dataframe for the year 2019.

all_trips <- bind_rows(q1_2019, q2_2019, q3_2019, q4_2019)

# Inspect the new dataframe

glimpse(all_trips)

# Look at the first six rows of all_trips

View(all_trips)

# Now we will start to clean the data by looking for missing values, duplicate rows, and incorrectly formatted values. First, I checked whether there were any duplicate values in the `trip_id` column, because all of the values in this column should be distinct:

sum(duplicated(all_trips$trip_id))

# There are no duplicate values in the `trip_id` column, so the `all_trips` data frame does not have any duplicate rows. Next, I looked at the distinct values in the `gender` and `usertype` columns, to make sure that neither column had values that were formatted or inserted incorrectly:

unique(all_trips$gender)
unique(all_trips$usertype)

# The only two user types are "Subscriber" and "Customer". We will have to rename "Subscriber" to "Member" and "Customer" to "Casual".

all_trips <- all_trips %>% mutate(usertype = recode(usertype, "Subscriber" = "Member", "Customer" = "Casual"))

# Check that the usertype column now has the new correct values

unique(all_trips$usertype)

# We will now remove any rows that contain null values.

all_trips <- all_trips %>% drop_na()

# We now look at the birth years, to ensure that they make sense.
n_distinct(all_trips$birthyear)
unique(all_trips$birthyear)

# There are 89 different birth years in the data, but some of them do not make sense for the year 2019: 1900, 1909, 1759, 1790, 1901, 1905, 1904, 1899, 1889. We should probably remove the rows that contain these birth years. 

# Find out how many rows have a birth year before 1910:

sum(all_trips$birthyear < 1910)

# There are 678 rows with a birth year before 1910, so we should probably remove these rows, because the birth year was likely input incorrectly. 

all_trips <- all_trips %>% filter(birthyear >= 1910)

# Check that there are now no rows with a birthyear before 1910:

sum(all_trips$birthyear < 1910)

# Look at a summary of the dataframe

summary(all_trips)

# The max tripduration is 9,056,633 seconds, which seems unlikely. We may want to add our own ride length column and then delete the tripduration column, in case some of the trip durations were input incorrectly. 

sum(all_trips$tripduration == difftime(all_trips$end_time,all_trips$start_time, units="secs"))

# There are (only) 2,307,800 rows where the trip duration column is equal to the time difference in seconds between the start and end times, which suggests that over one million rows do not have the correct trip duration value. So I will drop the tripduration column and then create a new, correct column for trip duration.

all_trips <- all_trips %>% select(-tripduration)

# Check that the new data frame does not have the trip duration column.

colnames(all_trips)

# Add a correct trip duration column to the data frame

all_trips <- all_trips %>% mutate(trip_duration = difftime(all_trips$end_time,all_trips$start_time, units="secs"), 
                                  .after=end_time)

# Convert "trip_duration" to numeric so we can run calculations on the data

is.numeric(all_trips$trip_duration)
all_trips$trip_duration <- as.numeric(as.character(all_trips$trip_duration))
is.numeric(all_trips$trip_duration)

# Summarize the data for the new trip_duration column

summary(all_trips$trip_duration)

# Now the minimum trip duration is negative, and the maximum is over 9 million seconds (104 days). There are 86,400 seconds in one day and 2,592,000 million seconds in 30 days, so let's see how many trip durations are longer than that.

sum(all_trips$trip_duration > 86400)

# There are 881 trip durations longer than one day. Let's try one week, which has 604,800 seconds.

sum(all_trips$trip_duration > 604800)

# There are 169 trip durations longer than one week. Let's try one month.

sum(all_trips$trip_duration > 2592000)

# There are 48 trip durations longer than one month. I guess people can book bikes for as long as they want, so a maximum trip duration of over 104 days must be possible. But we should certainly remove all the negative trip durations. How many do we have of those?

sum(all_trips$trip_duration <= 0)

# There are 8 negative trip durations. We will now remove those.

all_trips <- all_trips %>% filter(trip_duration > 0)

# Check that the desired rows have been removed

sum(all_trips$trip_duration <= 0)

# Check the station names to see if any seem obviously incorrect

unique(all_trips$from_station_name)
unique(all_trips$to_station_name)

# None of them seem obviously incorrect, so I won't clean those

# Currently we can only aggregate the data based on the ride level, which is too granular. So I will add some additional columns for the date, month, and day of each ride (I don't need to add a column for the year, because the data is all from 2019).

all_trips <- all_trips %>% 
  mutate(
    date = as.Date(all_trips$start_time),
    month = format(as.Date(date), "%m"),
    day = format(as.Date(date), "%d"),
    day_of_week = format(as.Date(date), "%A")) 

# Add a column for age

all_trips <- all_trips %>% 
  mutate(age = 2019 - birthyear) 

# Add a column for the season

all_trips <- all_trips %>% 
  mutate(
    season = case_when(
      month %in% c("12", "01", "02") ~ "winter",
      month %in% c("03", "04", "05") ~ "spring",
      month %in% c("06", "07", "08") ~ "summer",
      month %in% c("09", "10", "11") ~ "fall"
    )
  )

# Add a column to test if the trip started and ended at the same station (1 if yes, 0 if no)

all_trips <- all_trips %>% 
  mutate(round_trip = if_else(from_station_id == to_station_id, 1, 0)) 

# Add a column for time, so that we can then add columns for time of day

all_trips <- all_trips %>% 
  mutate(time = format(start_time, format="%H:%M:%S"))

# Add a column for time of day

all_trips <- all_trips %>% 
  mutate(
    time_of_day = case_when(
      "00:00:00" <= all_trips$time & all_trips$time <= "06:00:00"  ~ "early morning",
      "06:00:00" < all_trips$time & all_trips$time <= "12:00:00"  ~ "morning",
      "12:00:00" < all_trips$time & all_trips$time <= "18:00:00"  ~ "afternoon",
      "18:00:00" < all_trips$time & all_trips$time <= "23:59:59"  ~ "evening"
    )
  )

# Add a column for weekday/weekend

all_trips <- all_trips %>% 
  mutate(
    time_of_week = ifelse(day_of_week %in% c("Saturday", "Sunday"), "weekend", "weekday")
  ) 

# This completes the data wrangling process. We will now start to analyze the data to determine how annual members and casual riders use Cyclistic bikes differently.

# First we will compare annual members and casual riders with respect to number of rides, average and median ride lengths, most popular day of the week, average and median ages, most common age, most popular month, season, time of day, and time of week:

install.packages("DescTools") # We need the DescTools package to use the Mode() function.
library(DescTools)

all_trips %>% 
  group_by(usertype) %>% 
  summarize(
    number_of_rides = n(),
    average_ride_length = mean(trip_duration),
    median_ride_length = median(trip_duration),
    most_popular_day = Mode(day_of_week),
    average_age = mean(age),
    median_age = median(age),
    mode_age = Mode(age),
    most_popular_month = Mode(month),
    most_popular_season = Mode(season),
    most_popular_time_of_day = Mode(time_of_day),
    most_popular_time_of_week = Mode(time_of_week),
  ) %>% 
  glimpse()

# We see that the average and median ride lengths are much longer for casual vs. annual members: for casual members, the average and median ride lengths are respectively 2869 and 1386 seconds, while for annual members they are respectively 859 and 588 seconds. Also, the most popular for casual riders is Saturday, while for annual members it is Tuesday. Casual riders are also younger (on average) than annual members: the average and median ages for casual riders are respectively 30.9 and 28, while those for annual members are respectively 35.4 and 32 (also, the most common age for casual riders is 25, while for annual members it is 27). For both kinds of riders, the most popular riding season is the summer (specifically, August), the most popular time of day is the afternoon, and the most popular time of the week is during the week (as opposed to the weekend). Annual members also took far more rides: 2,913,956 for annual members vs. only 344,154 for casual riders. 

# Notice that the days of the week are out of order. Let's fix that.

all_trips$day_of_week <- ordered(all_trips$day_of_week, levels=c("Sunday", "Monday",
                                                                       "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"))

# Now we will compare annual members and casual riders by each day of the week, with respect to number of rides, average ride length, most popular month, season, and time of day:

all_trips %>% 
  group_by(usertype, day_of_week) %>% 
  summarize(
    number_of_rides = n(),
    average_ride_length = mean(trip_duration),
    most_popular_month = Mode(month),
    most_popular_season = Mode(season),
    most_popular_time_of_day = Mode(time_of_day),
  ) %>%
  arrange(usertype, day_of_week) 

# We see that casual riders (on average) take their longest rides on Fridays, while annual riders do so on Saturdays. For both kinds of riders and all days of the week, the most popular season was summer and the most popular time of day was the afternoon. We also reconfirm that the most popular day for casual riders is Friday, while for annual members it is Tuesday. 

# We now want to calculate the gender proportions of casual riders vs. annual members.

all_trips %>% 
  group_by(usertype) %>% 
  summarize(
    percent_male_trips = sum(gender == 'Male')/n(),
    percent_female_trips = sum(gender == 'Female')/n(),
  )

# We see that of the casual rider trips, 61.8% were male and 38.2% were female, while of the annual member trips, 75.1% were male and 24.9% were female. So annual members seem to have a greater proportion of males than casual riders. 

# We now want to calculate what proportion of the casual vs. annual trips were round trips.

all_trips %>% 
  group_by(usertype) %>% 
  summarize(
    percent_round_trips = sum(round_trip)/n()
  )

# So 8.45% of the casual rider trips were round trips, whereas only 1.6% of the annual member trips were round trips.

# Summary of most important differences between casual riders and annual members:
# Casual members take longer rides
# Casual members prefer riding on the weekend (Friday and Saturday), while annual members ride the most on Tuesdays (although annual members take their longest rides on Saturdays)
# Casual members are slightly younger
# Annual members took far more rides
# Annual members have a greater proportion of males than casual riders (75% male vs. 61% male)
# Casual riders are slightly more likely to return the bike back to the starting location

# Let's now visualize some of these important differences.

# First, we'll visualize the difference in average ride length (by day of the week)

all_trips %>% 
  group_by(usertype, day_of_week) %>% 
  summarize(
    number_of_rides = n(),
    average_ride_length = mean(trip_duration),
    most_popular_month = Mode(month),
    most_popular_season = Mode(season),
    most_popular_time_of_day = Mode(time_of_day),
    avg_ride_length_mins = average_ride_length/60
  ) %>%
  arrange(usertype, day_of_week) %>% 
  ggplot() + 
  geom_col(mapping = aes(x = day_of_week, y = avg_ride_length_mins, fill = usertype), position = "dodge") +
  labs(
    title = "Average ride length by user type and day of the week",
    subtitle = "Casual riders have much longer average rides (especially on Friday)",
    x = " ",
    y = "Average ride length (mins)",
    fill = " "
  )

# Now we'll visualize the differences in numbers of rides (by day of the week)

all_trips %>% 
  group_by(usertype, day_of_week) %>% 
  summarize(
    number_of_rides = n(),
    average_ride_length = mean(trip_duration),
    most_popular_month = Mode(month),
    most_popular_season = Mode(season),
    most_popular_time_of_day = Mode(time_of_day),
    avg_ride_length_mins = average_ride_length/60
  ) %>%
  arrange(usertype, day_of_week) %>% 
  ggplot() + 
  geom_col(mapping = aes(x = day_of_week, y = number_of_rides/1000, fill = usertype), position = "dodge") +
  labs(
    title = "Nunber of rides per day of the week by user type",
    subtitle = "Annual members prefer weekday rides, while casual riders prefer weekend rides",
    x = " ",
    y = "Number of rides (thousands)",
    fill = " "
  )

# Lastly, we'll visualize the gender proportions by user type

ggplot(all_trips) + 
  geom_bar(mapping = aes(x = usertype, fill = gender), position = "fill") +
  labs(
    title = "Gender proportions by user type",
    subtitle = "Annual members are more male-dominated",
    x = " ",
    y = " ",
    fill = " "
  )

sum(duplicated(all_trips$trip_id))
