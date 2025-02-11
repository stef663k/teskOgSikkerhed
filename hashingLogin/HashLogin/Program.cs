using System;
using System.Reflection.Metadata;
using System.Text;
using HashLogin.Models;
using HashLogin.Service;


namespace HashLogin;

public class Program
{
    private const string UserFile = "users.txt";
    public static void Main(string[] args)
    {
        if (!File.Exists(UserFile))
        {
            var adminHash = Hashing.ComputeHash("admin");
            File.WriteAllText(UserFile, $"admin:{adminHash}", Encoding.UTF8);
        }
        else 
        {
            // Validate existing entries
            var validLines = File.ReadAllLines(UserFile)
                .Where(line => line.Contains(':') && line.Split(':').Length == 2)
                .ToList();
            File.WriteAllLines(UserFile, validLines);
        }

        while (true)
        {
            Console.WriteLine("1. Create new user");
            Console.WriteLine("2. Login");
            Console.WriteLine("3. Delete user");
            Console.WriteLine("4. Bulk create test users");
            Console.WriteLine("0. Exit");
            Console.WriteLine("Choose an option: ");

            var choice = Console.ReadLine();

            switch (choice)
            {
                case "1":
                    CreateUser();
                    break;
                case "2":
                    Console.Clear();
                    bool isValid = Login();
                    Console.WriteLine(isValid ? "Login successful!" : "Invalid credentials!");
                    Console.ReadKey();
                    break;
                case "3":
                    DeleteUser();
                    break;
                case "4":
                    BulkCreateTestUsers();
                    break;
                case "0":
                    return;
                default:
                    Console.WriteLine("Invalid option");
                    break;
            }
        }
    }

    private static void DeleteUser()
    {
        Console.Write("Enter username to delete: ");
        string? username = Console.ReadLine()?.Trim();
        
        if (string.IsNullOrWhiteSpace(username))
        {
            Console.WriteLine("Username cannot be empty!");
            return;
        }

        var tempFile = Path.GetTempFileName();
        var deleted = false;

        foreach (var line in File.ReadLines(UserFile, Encoding.UTF8))
        {
            var parts = line.Split(':');
            
            if (parts is [{ } lineUsername, _] && 
                lineUsername.Equals(username, StringComparison.OrdinalIgnoreCase))
            {
                deleted = true;
                continue;
            }
            
            File.AppendAllText(tempFile, line + Environment.NewLine);
        }

        if (deleted)
        {
            File.Replace(tempFile, UserFile, null);
            Console.WriteLine($"User {username} deleted.");
        }
        else
        {
            File.Delete(tempFile);
            Console.WriteLine("User not found.");
        }
    }

    public static void CreateUser()
    {
        try 
        {
            Console.Write("Enter username: ");
            string username = Console.ReadLine()?.Trim() ?? "";
            
            Console.Write("Enter password: ");
            string password = GetMaskedPassword().Trim();
            
            var user = new User(username, password);
            
            File.AppendAllText(UserFile, 
                $"{user.Username}:{user.PasswordHash}{Environment.NewLine}", 
                Encoding.UTF8);
            
            Console.WriteLine("User created successfully!");
        }
        catch (UnauthorizedAccessException)
        {
            Console.WriteLine("Error: No write permission for users.txt");
        }
        catch (IOException ex)
        {
            Console.WriteLine($"File error: {ex.Message}");
        }
    }

    private static bool Login()
    {
        Console.Write("Enter username: ");
        string username = Console.ReadLine()?.Trim() ?? "";
        
        Console.Write("Enter password: ");
        string password = GetMaskedPassword();
        
        return Login(username, password);
    }

    private static bool Login(string username, string password)
    {
        return File.ReadLines(UserFile, Encoding.UTF8)
            .Select(line => line.Trim())
            .Where(line => !string.IsNullOrEmpty(line))
            .Select(line => line.Split(':'))
            .Any(parts => parts.Length == 2 &&
                 parts[0].Equals(username, StringComparison.OrdinalIgnoreCase) &&
                 Hashing.VerifyHash(password, parts[1]));
    }

    private static void BulkCreateTestUsers()
    {
        const int batchSize = 1000;
        var random = new Random();
        var existingNames = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        int startNumber = 1;

        if (File.Exists(UserFile))
        {
            foreach (var line in File.ReadLines(UserFile, Encoding.UTF8))
            {
                var parts = line.Split(':');
                if (parts.Length > 0)
                {
                    var username = parts[0].Trim();
                    existingNames.Add(username);
                    
                    if (username.StartsWith("testuser") && 
                        int.TryParse(username.AsSpan(8), out int num))
                    {
                        startNumber = Math.Max(startNumber, num + 1);
                    }
                }
            }
        }

        var newUsers = new List<string>();
        for (int i = 0; i < batchSize; i++)
        {
            var username = $"testuser{startNumber + i}";
            var password = $"Password{random.Next(100000, 999999)}!";
            newUsers.Add($"{username}:{Hashing.ComputeHash(password)}");
        }

        File.AppendAllLines(UserFile, newUsers);
        Console.WriteLine($"Created {batchSize} new users starting from testuser{startNumber}\n");
    }

    private static string GetMaskedPassword()
    {
        var password = new StringBuilder();
        while (true)
        {
            var key = Console.ReadKey(intercept: true);
            if (key.Key == ConsoleKey.Enter)
                break;
            
            if (key.Key == ConsoleKey.Backspace && password.Length > 0)
            {
                Console.Write("\b \b");
                password.Remove(password.Length - 1, 1);
            }
            else if (!char.IsControl(key.KeyChar))
            {
                Console.Write("*");
                password.Append(key.KeyChar);
            }
        }
        Console.WriteLine();
        return password.ToString();
    }
}