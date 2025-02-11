using System;
using System.Reflection.Metadata;
using HashLogin.Models;
using HashLogin.Service;


namespace HashLogin;

public class Program
{
    private const string UserFile = "users.txt";
    public static void Main(string[] args)
    {
        while (true)
        {
            Console.WriteLine("1. Create new user");
            Console.WriteLine("2. Login");
            Console.WriteLine("3. Delete user");
            Console.WriteLine("0. Exit");
            Console.WriteLine("Choose an option: ");

            var choice = Console.ReadLine();

            switch (choice)
            {
                case "1":
                    CreateUser();
                    break;
                case "2":
                    Login();
                    break;
                case "3":
                    DeleteUser();
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
        var username = Console.ReadLine()?.Trim();

        Console.Write("Enter password: ");
        var password = GetMaskedPassword();

        if (string.IsNullOrWhiteSpace(username) || string.IsNullOrWhiteSpace(password))
        {
            Console.WriteLine("Invalid input!\n");
            return;
        }

        var hashedPassword = Hashing.ComputeHash(password);
        var allUsers = File.ReadAllLines(UserFile).ToList();
        var initialCount = allUsers.Count;
        
        allUsers = allUsers.Where(line =>
        {
            var parts = line.Split(':');
            return parts.Length != 2 || 
                   !parts[0].Trim().Equals(username, StringComparison.OrdinalIgnoreCase) ||
                   parts[1].Trim() != hashedPassword;
        }).ToList();

        if (allUsers.Count < initialCount)
        {
            File.WriteAllLines(UserFile, allUsers);
            Console.WriteLine("User deleted successfully!\n");
        }
        else
        {
            Console.WriteLine("Invalid credentials or user not found!\n");
        }
    }

    private static void CreateUser()
    {
        string username;
        do
        {
            Console.Write("Enter username: ");
            username = Console.ReadLine() ?? string.Empty;
        } while (string.IsNullOrWhiteSpace(username));

        string password;
        do
        {
            Console.Write("Enter password: ");
            password = GetMaskedPassword();
        } while (string.IsNullOrWhiteSpace(password));

        var user = new User(username, password);
        File.AppendAllText(UserFile, $"{user.Username}:{user.PasswordHash}\n");
        Console.WriteLine("User created successfully!\n");
    }

    private static void Login()
    {
        Console.Write("Enter username: ");
        var username = Console.ReadLine();

        Console.Write("Enter password: ");
        var password = GetMaskedPassword();
        
        var hashedPassword = Hashing.ComputeHash(password);

        var validUser = File.ReadAllLines(UserFile)
            .Select(line => line.Split(':'))
            .Any(parts => parts.Length == 2 &&
            parts[0] == username &&
            parts[1] == hashedPassword);

        if (validUser)
        {
            Console.WriteLine("Login successful!\n");
        }
        else
        {
            Console.WriteLine("Invalid credentials!\n");
        }
    }

    

    private static string GetMaskedPassword()
    {
        var password = "";
        ConsoleKeyInfo key;

        do
        {
            key = Console.ReadKey(true);

            if (key.Key != ConsoleKey.Backspace && key.Key != ConsoleKey.Enter)
            {
                password += key.KeyChar;
                Console.Write("*");
            }
            else if (key.Key == ConsoleKey.Backspace && password.Length > 0)
            {
                password = password[0..^1];
                Console.Write("\b \b");
            }
        }
        while (key.Key != ConsoleKey.Enter);

        Console.WriteLine();
        return password;
    }
}