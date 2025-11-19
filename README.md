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

## Verify PostgreSQL Installation

Before starting the setup, let's make sure PostgreSQL is installed correctly and running.

### Check if PostgreSQL is Running

**Mac:**
```bash
brew services list
```
Look for `postgresql@16` with status "started". If it shows "stopped", start it:
```bash
brew services start postgresql@16
```

**Windows:**
1. Press `Win+R`, type `services.msc`, press Enter
2. Look for "PostgreSQL" in the services list
3. If stopped, right-click and select "Start"

**Linux (Ubuntu/Debian):**
```bash
sudo systemctl status postgresql
```
If not running:
```bash
sudo systemctl start postgresql
```

### Set Up PostgreSQL User

The application expects a PostgreSQL user named `postgres` with password `postgres`. Let's verify this exists:

**Mac:**
```bash
# Connect to PostgreSQL
psql postgres

# Inside psql, create the user if needed:
CREATE USER postgres WITH PASSWORD 'postgres' CREATEDB;

# Or if user exists, update password:
ALTER USER postgres WITH PASSWORD 'postgres';

# Grant superuser privileges (needed for database creation):
ALTER USER postgres WITH SUPERUSER;

# Exit psql
\q
```

**Windows:**
During PostgreSQL installation, you were asked to set a password for the `postgres` user. If you used a different password, you'll need to either:
1. Update it to `postgres`: Use pgAdmin or command line to change the password
2. Or update `config/dev.exs` to use your password

**Linux:**
```bash
# Switch to postgres system user
sudo -u postgres psql

# Inside psql:
ALTER USER postgres WITH PASSWORD 'postgres';
ALTER USER postgres WITH SUPERUSER;

# Exit psql
\q
```

### Test Database Connection

Before proceeding, test that you can connect:

```bash
psql -U postgres -h localhost -d postgres
```

When prompted, enter the password: `postgres`

If you see the `postgres=#` prompt, your database is ready! Type `\q` to exit.

If you get errors:
- **"psql: command not found"**: PostgreSQL may not be in your PATH
  - **Mac**: Run `brew info postgresql@16` for path instructions
  - **Windows**: Add PostgreSQL's bin directory to your PATH
- **"connection refused"**: PostgreSQL service is not running (see "Check if PostgreSQL is Running" above)
- **"authentication failed"**: Password is incorrect (see "Set Up PostgreSQL User" above)

## Pre-Setup Checklist

Before running `mix setup`, verify these requirements are met:

- [ ] PostgreSQL is installed and running (`brew services list` on Mac, `services.msc` on Windows, `systemctl status postgresql` on Linux)
- [ ] You can connect to PostgreSQL: `psql -U postgres -h localhost -d postgres` (password: `postgres`)
- [ ] Elixir is installed: `elixir --version` (should show version 1.19 or higher)
- [ ] Git is installed: `git --version`
- [ ] Port 4000 is available (not used by another application)
- [ ] Port 5432 is available for PostgreSQL

If any of these checks fail, refer back to the installation and verification sections above.

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

### Step 3: Set Up the Database and Assets

This single command sets up everything the application needs:

```bash
mix setup
```

#### What `mix setup` Does

Behind the scenes, this command runs several steps:

1. **`mix deps.get`** - Already done in Step 2, but ensures all dependencies are installed
2. **`mix ecto.create`** - Creates the PostgreSQL database `prime_youth_dev`
3. **`mix ecto.migrate`** - Runs database migrations (currently none, but prepares for future updates)
4. **`mix run priv/repo/seeds.exs`** - Seeds the database with initial data (currently empty)
5. **`mix assets.setup`** - Installs Tailwind CSS and esbuild for styling and JavaScript
6. **`mix assets.build`** - Compiles CSS and JavaScript assets

#### If `mix setup` Fails

If you encounter errors, you can run each command individually to identify where the problem is:

```bash
mix deps.get              # Install dependencies
mix ecto.create          # Create database only
mix ecto.migrate         # Run migrations only
mix assets.setup         # Install asset tools
mix assets.build         # Build assets
```

This helps isolate whether the issue is with:
- Database connection (ecto.create fails)
- Database migrations (ecto.migrate fails)
- Asset compilation (assets.setup or assets.build fails)

#### Database Configuration

**Note**: `mix setup` assumes PostgreSQL is running with default settings:
- Username: `postgres`
- Password: `postgres`
- Host: `localhost`
- Port: `5432`

If your PostgreSQL has different settings, edit `config/dev.exs` and update the database configuration section:

```elixir
config :prime_youth, PrimeYouth.Repo,
  username: "your_username",    # Change if different
  password: "your_password",    # Change if different
  hostname: "localhost",
  database: "prime_youth_dev"
```

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

This section covers common errors you might encounter during setup and how to fix them.

### Error: "role 'postgres' does not exist"

This means the PostgreSQL user hasn't been created yet.

**Solution:**

```bash
# Mac/Linux
psql postgres
CREATE USER postgres WITH PASSWORD 'postgres' SUPERUSER CREATEDB;
\q

# Or on Linux, you may need:
sudo -u postgres psql
CREATE USER postgres WITH PASSWORD 'postgres' SUPERUSER CREATEDB;
\q
```

**Windows:**
Use pgAdmin (installed with PostgreSQL) to create a user named `postgres` with password `postgres` and superuser privileges.

### Error: "password authentication failed for user 'postgres'"

The postgres user exists but has a different password than expected.

**Solution 1 - Update PostgreSQL password to match:**

```bash
psql postgres
ALTER USER postgres WITH PASSWORD 'postgres';
\q
```

**Solution 2 - Update config to match your password:**

Edit `config/dev.exs` and change the password to match your PostgreSQL setup:

```elixir
config :prime_youth, PrimeYouth.Repo,
  username: "postgres",
  password: "your_actual_password",  # Change this line
  hostname: "localhost",
  database: "prime_youth_dev"
```

### Error: "database 'prime_youth_dev' already exists"

The database exists but may be in a bad state from a previous setup attempt.

**Solution:**

```bash
mix ecto.drop     # Delete the existing database
mix ecto.create   # Create it fresh
mix ecto.migrate  # Run migrations
```

Or use the reset command which does all three:

```bash
mix ecto.reset
```

### Error: "could not connect to server" or "connection refused"

PostgreSQL is not running.

**Solution:**

**Mac:**
```bash
brew services start postgresql@16
```

**Windows:**
1. Press `Win+R`, type `services.msc`, press Enter
2. Find "PostgreSQL" in the list
3. Right-click and select "Start"

**Linux:**
```bash
sudo systemctl start postgresql
```

### Error: "permission denied to create database"

The postgres user doesn't have permission to create databases.

**Solution:**

```bash
psql postgres
ALTER USER postgres WITH CREATEDB SUPERUSER;
\q
```

### Error: Port 4000 Already in Use

Another application (or another instance of Phoenix) is using port 4000.

**Solution 1 - Find and stop the process:**

**Mac/Linux:**
```bash
lsof -i :4000      # Find the process using port 4000
kill -9 <PID>      # Kill it using the PID from above
```

**Windows:**
```cmd
netstat -ano | findstr :4000    # Find the process
taskkill /PID <PID> /F          # Kill it using the PID
```

**Solution 2 - Use a different port:**

Edit `config/dev.exs` and change the port:

```elixir
config :prime_youth, PrimeYouthWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],  # Change 4000 to 4001
```

### Error: Asset Compilation Failures

Errors during `mix assets.setup` or `mix assets.build`.

**Common causes:**
- esbuild or Tailwind installation failed
- Node.js version incompatibility

**Solution:**

```bash
# Clean and reinstall assets
mix assets.setup --force
mix assets.build
```

If that doesn't work, try:

```bash
# Remove compiled assets and try again
rm -rf _build
rm -rf deps
mix deps.get
mix assets.setup
mix assets.build
```

### Error: "mix: command not found"

Elixir is not installed or not in your PATH.

**Solution:**

**Mac:**
```bash
brew install elixir
```

**Windows/Linux:**
Follow the installation instructions at [elixir-lang.org](https://elixir-lang.org/install.html)

After installation, close and reopen your terminal to refresh the PATH.

### Error: Missing Dependencies or Compilation Errors

Stale dependencies or compilation artifacts causing issues.

**Solution:**

```bash
# Nuclear option - clean everything and start fresh
mix deps.clean --all
rm -rf _build
mix deps.get
mix compile
mix setup
```

### Database Connection Errors After Setup

Everything installed correctly but the app won't connect to the database when starting the server.

**Checklist:**

1. **Verify PostgreSQL is running:**
   ```bash
   # Mac
   brew services list

   # Linux
   sudo systemctl status postgresql
   ```

2. **Test database connection manually:**
   ```bash
   psql -U postgres -h localhost -d prime_youth_dev
   ```

3. **Check database exists:**
   ```bash
   psql -U postgres -h localhost -c "\l" | grep prime_youth
   ```

4. **If database doesn't exist, create it:**
   ```bash
   mix ecto.create
   ```

### General Debugging Steps

If you're stuck and nothing is working:

1. **Check all services are running:**
   - PostgreSQL on port 5432
   - No conflicts on port 4000

2. **Verify installations:**
   ```bash
   elixir --version  # Should show 1.19.x or higher
   psql --version    # Should show PostgreSQL
   ```

3. **Run setup steps individually:**
   ```bash
   mix deps.get
   mix ecto.create
   mix ecto.migrate
   mix assets.setup
   mix assets.build
   ```

   This helps identify exactly which step is failing.

4. **Check the error logs carefully** - they usually indicate exactly what's wrong

5. **Try resetting everything:**
   ```bash
   mix ecto.reset
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

## PostgreSQL Quick Reference

Common PostgreSQL commands you might need:

### Service Management

**Mac:**
```bash
brew services start postgresql@16   # Start PostgreSQL
brew services stop postgresql@16    # Stop PostgreSQL
brew services restart postgresql@16 # Restart PostgreSQL
brew services list                  # Check status
```

**Linux:**
```bash
sudo systemctl start postgresql     # Start PostgreSQL
sudo systemctl stop postgresql      # Stop PostgreSQL
sudo systemctl restart postgresql   # Restart PostgreSQL
sudo systemctl status postgresql    # Check status
```

**Windows:**
Use Services panel (`Win+R`, type `services.msc`) to start/stop/restart PostgreSQL service.

### Database Operations

```bash
# Connect to PostgreSQL
psql -U postgres -h localhost

# Connect to specific database
psql -U postgres -h localhost -d prime_youth_dev

# List all databases
psql -U postgres -h localhost -c "\l"

# Drop a database (careful!)
psql -U postgres -h localhost -c "DROP DATABASE prime_youth_dev;"

# Create a database
psql -U postgres -h localhost -c "CREATE DATABASE prime_youth_dev;"
```

### User Management

```bash
# Connect to postgres database
psql -U postgres -h localhost

# Inside psql:
CREATE USER postgres WITH PASSWORD 'postgres' SUPERUSER CREATEDB;  # Create user
ALTER USER postgres WITH PASSWORD 'new_password';                   # Change password
ALTER USER postgres WITH SUPERUSER CREATEDB;                        # Grant permissions
\du                                                                 # List all users
\q                                                                  # Quit psql
```

### Mix Commands for Database

```bash
mix ecto.create    # Create the database
mix ecto.drop      # Drop the database
mix ecto.migrate   # Run migrations
mix ecto.rollback  # Rollback last migration
mix ecto.reset     # Drop, create, and migrate
```

## Learn More About Phoenix

- Official website: https://www.phoenixframework.org/
- Guides: https://hexdocs.pm/phoenix/overview.html
- Docs: https://hexdocs.pm/phoenix
- Forum: https://elixirforum.com/c/phoenix-forum
