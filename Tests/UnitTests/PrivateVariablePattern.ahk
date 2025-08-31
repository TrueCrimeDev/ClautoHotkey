CreateAccount(initialBalance) {
    balance := initialBalance
    transactions := []

    return Map(
        "deposit", (amount) => (
            balance += amount,
            transactions.Push({type: "deposit", amount: amount}),
            balance
        ),
        "withdraw", (amount) => balance >= amount
            ? (balance -= amount, transactions.Push({type: "withdraw", amount: amount}), balance)
            : false,
        "getBalance", () => balance,
        "getHistory", () => transactions.Clone()
    )
}

account := CreateAccount(100)
account["deposit"](50)
account["withdraw"](30)
MsgBox("Balance: " . account["getBalance"]())