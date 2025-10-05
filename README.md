# Prime Youth - Local Development Setup

Prime Youth is a website for managing afterschool activities, camps, and class trips. This guide will help you get the application running on your computer so you can view the LiveView pages.

## What You'll Need

Before starting, you need to install these programs on your computer:

### 1. Elixir (Programming Language)
- **Mac**: Open Terminal and run: `brew install elixir`
- **Windows**: Download from [elixir-lang.org](https://elixir-lang.org/install.html)
- **Linux**: Follow instructions at [elixir-lang.org](https://elixir-lang.org/install.html)

### 2. PostgreSQL (Database)
- **Mac**: `brew install postgresql@16`
  - After installing, start PostgreSQL: `brew services start postgresql@16`
- **Windows**: Download from [postgresql.org](https://www.postgresql.org/download/windows/)
- **Linux**: `sudo apt-get install postgresql postgresql-contrib` (Ubuntu/Debian)

### 3. Git (if not already installed)
- **Mac**: Usually pre-installed, or install with: `brew install git`
- **Windows**: Download from [git-scm.com](https://git-scm.com/download/win)
- **Linux**: `sudo apt-get install git`

## Quick Start Guide

### Step 1: Get the Code

Open Terminal (Mac/Linux) or Command Prompt (Windows) and run:

```bash
git clone https://github.com/YOUR_USERNAME/prime-youth.git
cd prime-youth
```

### Step 2: Install Dependencies

This command installs all the packages the app needs:

```bash
mix deps.get
```

### Step 3: Set Up the Database

This creates the database and prepares it with the right structure:

```bash
mix setup
```

**Note**: This assumes PostgreSQL is running with default settings:
- Username: `postgres`
- Password: `postgres`
- Host: `localhost`

If your PostgreSQL has different settings, edit `config/dev.exs` and update the database configuration.

### Step 4: Start the Server

Run this command to start the application:

```bash
mix phx.server
```

You should see output like:
```
[info] Running PrimeYouthWeb.Endpoint with Bandit 1.5.7 at 127.0.0.1:4000 (http)
[info] Access PrimeYouthWeb.Endpoint at http://localhost:4000
```

### Step 5: View the Application

Open your web browser and go to:

**http://localhost:4000**

You should now see the Prime Youth website! 🎉

## Available Pages

Once the server is running, you can visit:

### Public Pages (No Login Required)
- **Homepage**: http://localhost:4000
- **Programs Catalog**: http://localhost:4000/programs
- **Program Details**: http://localhost:4000/programs/1 (example with program ID 1)
- **Program Booking**: http://localhost:4000/programs/1/booking
- **Login**: http://localhost:4000/login
- **Sign Up**: http://localhost:4000/signup

### Authenticated Pages (Require Login)
- **Dashboard**: http://localhost:4000/dashboard
- **Highlights**: http://localhost:4000/highlights
- **Settings**: http://localhost:4000/settings

### Developer Tools (Development Only)
- **Live Dashboard**: http://localhost:4000/dev/dashboard (monitoring and metrics)
- **Email Preview**: http://localhost:4000/dev/mailbox (view sent emails)

## Stopping the Server

To stop the application:
- Press `Ctrl+C` twice in the terminal where the server is running

## Troubleshooting

### Database Connection Error

If you see an error about connecting to the database:

1. Make sure PostgreSQL is running:
   - **Mac**: `brew services list` (should show postgresql as "started")
   - **Windows**: Check Services panel for "PostgreSQL"
   - **Linux**: `sudo systemctl status postgresql`

2. Check your database credentials in `config/dev.exs`:
   ```elixir
   config :prime_youth, PrimeYouth.Repo,
     username: "postgres",
     password: "postgres",
     hostname: "localhost",
     database: "prime_youth_dev"
   ```

3. If you need to reset the database:
   ```bash
   mix ecto.reset
   ```

### Port Already in Use

If port 4000 is already being used by another application:

1. Stop the other application, or
2. Change the port in `config/dev.exs` (search for `port:` and change 4000 to another number like 4001)

### Missing Dependencies

If you see errors about missing packages:

```bash
mix deps.clean --all
mix deps.get
mix setup
```

## Making Changes

The application automatically reloads when you make changes to files:

- **Code changes**: Edit files in `lib/prime_youth_web/`
- **Styling**: Edit files in `assets/css/`
- **Just save the file** and refresh your browser - the changes should appear!

## For Developers

### Running Tests
```bash
mix test
```

### Interactive Console
To start the server with an interactive Elixir console:
```bash
iex -S mix phx.server
```

### Resetting Everything
If you need to start fresh:
```bash
mix ecto.reset
mix deps.clean --all
mix deps.get
mix setup
```

## Need Help?

If you run into issues:

1. Check the troubleshooting section above
2. Make sure all prerequisites are installed correctly
3. Create an issue on GitHub with:
   - What command you ran
   - The error message you received
   - Your operating system

## Learn More About Phoenix

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
