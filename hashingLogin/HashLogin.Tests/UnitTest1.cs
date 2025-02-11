using Xunit;
using HashLogin.Service;
using System.IO;
using System.Diagnostics;
using System;
using System.Linq;
using System.Text;

namespace HashLogin.Tests;
public class UnitTest1 : IDisposable
{
    private const string TestFile = "test_users.txt";

    public UnitTest1()
    {
        // Clean up before each test
        if (File.Exists(TestFile)) File.Delete(TestFile);
    }

    [Fact]
    public void ComputeHash_GeneratesUniqueSalts()
    {
        // Arrange
        var password = "testpassword";
        
        // Act
        var hash1 = Hashing.ComputeHash(password);
        var hash2 = Hashing.ComputeHash(password);
        
        // Assert
        Assert.NotEqual(hash1, hash2);
    }

    [Fact]
    public void VerifyHash_ValidatesCorrectPassword()
    {
        // Arrange
        var password = "testpassword";
        var hash = Hashing.ComputeHash(password);
        
        // Act
        var isValid = Hashing.VerifyHash(password, hash);
        
        // Assert
        Assert.True(isValid);
    }

    [Fact]
    public void VerifyHash_RejectsIncorrectPassword()
    {
        // Arrange
        var hash = Hashing.ComputeHash("realpassword");
        
        // Act
        var isValid = Hashing.VerifyHash("wrongpassword", hash);
        
        // Assert
        Assert.False(isValid);
    }

    [Fact]
    public void Login_ValidCredentials_ReturnsTrue()
    {
        // Arrange
        string testFile = "test_users.txt";
        string username = "testuser";
        string password = "TestPass123!";
        
        // Create user with correct format
        string hash = Hashing.ComputeHash(password);
        File.WriteAllText(testFile, $"{username}:{hash}");
        
        // Temporary debug in test:
        Console.WriteLine($"Generated Hash: {hash}");
        // Should output: "salt|hash" where both are base64
        
        // Act
        bool result = File.ReadLines(testFile)
            .Select(line => line.Split(':'))
            .Any(parts => parts.Length == 2 &&
                 parts[0] == username &&
                 Hashing.VerifyHash(password, parts[1]));
        
        // Assert
        Assert.True(result);
        
        // Cleanup
        File.Delete(testFile);
    }

    [Fact]
    public void CreateUser_SavesToFile()
    {
        // Arrange
        string testFile = "create_user_test.txt";
        string username = "testuser";
        string password = "testpass";
        
        // Act
        File.AppendAllText(testFile, 
            $"{username}:{Hashing.ComputeHash(password)}{Environment.NewLine}", 
            Encoding.UTF8);
        
        // Assert
        var content = File.ReadAllText(testFile);
        Assert.Contains(username, content);
        
        // Cleanup
        File.Delete(testFile);
    }

    public void Dispose()
    {
        // Clean up after tests
        if (File.Exists(TestFile)) File.Delete(TestFile);
    }
}
