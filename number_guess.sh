#!/bin/bash

PSQL="psql --username=freecodecamp --dbname=number_guess -t --no-align -c"

# Function to validate database connection
check_db_connection() {
  if ! $PSQL "SELECT 1" > /dev/null 2>&1; then
    echo "Error: Cannot connect to database"
    exit 1
  fi
}

# Function to generate a random number between 1 and 1000
generate_secret_number() {
  echo $((RANDOM % 1000 + 1))
}

# Function to get user stats from database
get_user_stats() {
  local username=$1
  $PSQL "SELECT games_played, best_game FROM users WHERE username = '$username'"
}

# Function to insert new user into database
insert_new_user() {
  local username=$1
  $PSQL "INSERT INTO users(username, games_played, best_game) VALUES('$username', 0, NULL)" > /dev/null
}

# Function to update user stats after a game
update_user_stats() {
  local username=$1
  local num_guesses=$2
  local games_played=$3
  local best_game=$4
  
  if [[ -z "$best_game" ]] || (( num_guesses < best_game )); then
    $PSQL "UPDATE users SET games_played = $games_played, best_game = $num_guesses WHERE username = '$username'" > /dev/null
  else
    $PSQL "UPDATE users SET games_played = $games_played WHERE username = '$username'" > /dev/null
  fi
}

# Main game logic
main() {
  # Check database connection
  check_db_connection
  
  # Ask for username
  echo "Enter your username:"
  read USERNAME
  
  # Check if username exists in database
  USER_RESULT=$(get_user_stats "$USERNAME")
  
  if [[ -z "$USER_RESULT" ]]; then
    # New user
    echo "Welcome, $USERNAME! It looks like this is your first time here."
    # Insert new user
    insert_new_user "$USERNAME"
  else
    # Returning user
    IFS='|' read -r GAMES_PLAYED BEST_GAME <<< "$USER_RESULT"
    echo "Welcome back, $USERNAME! You have played $GAMES_PLAYED games, and your best game took $BEST_GAME guesses."
  fi
  
  # Generate secret number
  SECRET_NUMBER=$(generate_secret_number)
  
  # Game loop
  echo "Guess the secret number between 1 and 1000:"
  NUMBER_OF_GUESSES=0
  
  while true; do
    read GUESS
    
    # Check if input is an integer
    if ! [[ "$GUESS" =~ ^[0-9]+$ ]]; then
      echo "That is not an integer, guess again:"
      continue
    fi
    
    ((NUMBER_OF_GUESSES++))
    
    if (( GUESS < SECRET_NUMBER )); then
      echo "It's higher than that, guess again:"
    elif (( GUESS > SECRET_NUMBER )); then
      echo "It's lower than that, guess again:"
    else
      # Correct guess
      echo "You guessed it in $NUMBER_OF_GUESSES tries. The secret number was $SECRET_NUMBER. Nice job!"
      
      # Update user record
      if [[ -z "$USER_RESULT" ]]; then
        # First game for this user
        update_user_stats "$USERNAME" "$NUMBER_OF_GUESSES" 1 ""
      else
        # Update games_played
        GAMES_PLAYED=$((GAMES_PLAYED + 1))
        update_user_stats "$USERNAME" "$NUMBER_OF_GUESSES" "$GAMES_PLAYED" "$BEST_GAME"
      fi
      
      break
    fi
  done
}

# Run main function
main
