import requests
import json
import os
import time
import subprocess
import socket  # Needed for IPC with MPV
import sys
from termcolor import cprint, colored
from pick import pick
from pyfiglet import Figlet

HISTORY_FILE = "popcorn_history.json"
MPV_IPC_SOCKET = "/tmp/mpv-socket"

def boot_animation():
    fig = Figlet(font='slant')
    boot_art = fig.renderText("Popcorn CLI")
    cprint(boot_art, "green")
    cprint("Starting up...", "blue")
    time.sleep(2)

def search_movies(query):
    url = f"https://yts.mx/api/v2/list_movies.json?query_term={query}"
    response = requests.get(url)
    if response.status_code == 200:
        data = response.json()
        return data['data']['movies'] if data['data']['movie_count'] > 0 else None
    else:
        return None

def select_movie(movies):
    movie_options = [f"{movie['title']} ({movie['year']})" for movie in movies]
    cprint("Select a movie:", "cyan")
    option, index = pick(movie_options, "Available movies:")
    return movies[index]

def select_variant(movie):
    variant_options = [
        f"{t['quality']} - {t['size']} - Seeds: {t['seeds']}"
        for t in movie['torrents']
    ]
    cprint(f"\nVariants for {movie['title']}:", "cyan")
    option, index = pick(variant_options, "Select a variant:")
    return movie['torrents'][index]

def load_history():
    if os.path.exists(HISTORY_FILE):
        with open(HISTORY_FILE, 'r') as f:
            return json.load(f)
    return {}

def save_history(history):
    with open(HISTORY_FILE, 'w') as f:
        json.dump(history, f, indent=4)

def check_history(movie_name):
    history = load_history()
    return history.get(movie_name, None)

def show_progress_bar(total, current):
    bar_length = 40
    filled_length = int(bar_length * current // total)
    bar = '█' * filled_length + '-' * (bar_length - filled_length)
    percent = round(100.0 * current / float(total), 1)
    sys.stdout.write(f'\r|{bar}| {percent}%')
    sys.stdout.flush()

def watch_movie(torrent, movie_name):
    torrent_url = torrent['url']
    cprint("\nStreaming via Peerflix...", "yellow")
    cprint(f"Opening {movie_name} in MPV...", "green")

    # Start Peerflix and capture the output
    peerflix_process = subprocess.Popen(
        ["peerflix", torrent_url, "--mpv", f"--mpv-args=--input-ipc-server={MPV_IPC_SOCKET}"],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    # Track progress
    for line in peerflix_process.stdout:
        if "verifying" in line.lower() or "downloading" in line.lower():
            if "downloading" in line.lower():
                # Show some progress bar based on the percentage mentioned in the output line
                parts = line.split()
                try:
                    progress_index = parts.index('Downloading') + 1
                    progress = parts[progress_index].strip('%')
                    progress_value = float(progress)
                    show_progress_bar(100, progress_value)
                except (ValueError, IndexError):
                    continue
        elif "server is running" in line.lower():
            # Hide unnecessary outputs
            cprint("\nMovie is buffering and starting...", "yellow")
        elif "time out" in line.lower():
            cprint("\nBuffering timed out. You might want to try again.", "red")
            break
    
    peerflix_process.wait()

def send_mpv_command(command):
    """Send a command to MPV via the IPC socket."""
    try:
        client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        client.connect(MPV_IPC_SOCKET)
        client.sendall(json.dumps(command).encode('utf-8'))
        client.close()
    except Exception as e:
        cprint(f"Failed to send command to MPV: {e}", "red")

def command_interface(mpv_process):
    """Command interface to control movie playback."""
    cprint("\nControl the playback with the following commands:", "cyan")
    cprint("pause - Pause the movie", "yellow")
    cprint("resume - Resume the movie", "yellow")
    cprint("stop - Stop the movie", "yellow")
    cprint("seek +10 - Seek forward 10 seconds", "yellow")
    cprint("seek -10 - Seek backward 10 seconds", "yellow")
    cprint("exit - Exit the command interface and stop the movie", "yellow")
    
    while True:
        command = input(colored(">> ", "blue")).strip().lower()

        if command == "pause":
            send_mpv_command({"command": ["set_property", "pause", True]})
        elif command == "resume":
            send_mpv_command({"command": ["set_property", "pause", False]})
        elif command == "stop":
            send_mpv_command({"command": ["quit"]})
            break
        elif command.startswith("seek"):
            _, seconds = command.split()
            send_mpv_command({"command": ["seek", int(seconds), "relative"]})
        elif command == "exit":
            send_mpv_command({"command": ["quit"]})
            break
        else:
            cprint("Unknown command. Try again.", "red")
    
    cprint("Exiting movie...", "red")
    mpv_process.terminate()

def display_movie_info(movie, torrent):
    cprint("\n=======================================", "blue")
    cprint(f" Title: {movie['title']}", "magenta")
    cprint(f" Year: {movie['year']}", "magenta")
    cprint(f" Quality: {torrent['quality']}", "magenta")
    cprint(f" Size: {torrent['size']}", "magenta")
    cprint(f" Seeds: {torrent['seeds']}", "magenta")
    cprint(f" URL: {torrent['url']}", "magenta")
    cprint("=======================================\n", "blue")

def main():
    boot_animation()
    
    # Search for the movie
    query = input(colored("Enter the movie name: ", "yellow"))
    movies = search_movies(query)
    
    if not movies:
        cprint("No movies found. Try another name.", "red")
        return
    
    # Select a movie
    movie = select_movie(movies)
    
    # Select a variant
    torrent = select_variant(movie)

    # Display selected movie info
    display_movie_info(movie, torrent)
    
    # Check history
    history = check_history(movie['title'])
    if history:
        cprint(f"You have watched {movie['title']} before. Last stopped at: {history['time']}", "yellow")
    
    # Watch the movie
    mpv_process = watch_movie(torrent, movie['title'])

    # Command interface for user control
    command_interface(mpv_process)

    # Update history (for simplicity, we're not tracking time here)
    history = load_history()
    history[movie['title']] = {'time': '00:00:00'}
    save_history(history)

if __name__ == "__main__":
    main()
