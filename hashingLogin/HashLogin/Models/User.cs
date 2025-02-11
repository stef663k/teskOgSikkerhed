using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using HashLogin.Service;

namespace HashLogin.Models;

public class User
{
    public string Username { get; }
    public string PasswordHash { get; }

    public User(string username, string password)
    {
        Username = username.Trim().ToLowerInvariant();
        PasswordHash = Hashing.ComputeHash(password.Trim());
    }
}