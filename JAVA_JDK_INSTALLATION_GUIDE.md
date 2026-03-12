# Java JDK Installation and Setup Guide for Windows

## Step 1: Download Java JDK
1. Go to the official Oracle JDK download page: https://www.oracle.com/java/technologies/downloads/
2. Download the latest JDK version for Windows (e.g., Windows x64 Installer).

## Step 2: Install Java JDK
1. Run the downloaded installer.
2. Follow the installation wizard and install JDK to the default location (e.g., `C:\Program Files\Java\jdk-XX.X.X`).

## Step 3: Set Environment Variables
1. Open **Start Menu** and search for **Environment Variables**.
2. Click **Edit the system environment variables**.
3. In the System Properties window, click **Environment Variables**.
4. Under **System variables**, find and select the `Path` variable, then click **Edit**.
5. Click **New** and add the path to the JDK `bin` directory, e.g.:
   ```
   C:\Program Files\Java\jdk-XX.X.X\bin
   ```
6. Click **OK** on all dialogs to save.

## Step 4: Verify Installation
1. Open a new Command Prompt window.
2. Run:
   ```
   java -version
   ```
   You should see the installed Java version.
3. Run:
   ```
   keytool
   ```
   You should see the keytool usage information.

## Step 5: Get SHA-1 and SHA-256 Fingerprints
1. Run the following command in Command Prompt:
   ```
   keytool -list -v -alias androiddebugkey -keystore %USERPROFILE%\.android\debug.keystore -storepass android -keypass android
   ```
2. Look for the `SHA1` and `SHA256` values in the output.

---

If you want, I can help you with the next steps after you have Java JDK installed and can run `keytool`.
