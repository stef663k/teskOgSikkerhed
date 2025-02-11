using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using HashLogin.Service;

namespace HashLogin.Models;

public class User
{
    public int userid { get; set; }
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;

    public User(string username, string password)
    {
        Username = username;
        PasswordHash = Hashing.ComputeHash(password);
    }
}