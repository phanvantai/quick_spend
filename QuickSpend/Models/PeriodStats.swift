import Foundation

/// Statistics for a specific time period (computed, not persisted)
struct PeriodStats {
    let totalAmount: Double
    let totalIncome: Double
    let totalExpenses: Double
    let netBalance: Double
    let savingsRate: Double
    let transactionCount: Int
    let incomeCount: Int
    let expenseCount: Int
    let averagePerDay: Double
    let averagePerTransaction: Double
    let highestExpense: Transaction?
    let lowestExpense: Transaction?
    let highestIncome: Transaction?
    let lowestIncome: Transaction?
    let categoryBreakdown: [CategoryStats]
    let dailySpending: [Date: Double]
    let dailyIncome: [Date: Double]
    let dailyNet: [Date: Double]
    let startDate: Date
    let endDate: Date
    let categoryTotals: [String: Double]
    let categoryCounts: [String: Int]

    /// Create empty statistics
    static func empty(startDate: Date, endDate: Date) -> PeriodStats {
        PeriodStats(
            totalAmount: 0, totalIncome: 0, totalExpenses: 0,
            netBalance: 0, savingsRate: 0,
            transactionCount: 0, incomeCount: 0, expenseCount: 0,
            averagePerDay: 0, averagePerTransaction: 0,
            highestExpense: nil, lowestExpense: nil,
            highestIncome: nil, lowestIncome: nil,
            categoryBreakdown: [],
            dailySpending: [:], dailyIncome: [:], dailyNet: [:],
            startDate: startDate, endDate: endDate,
            categoryTotals: [:], categoryCounts: [:]
        )
    }

    /// Calculate statistics from a list of transactions
    static func fromTransactions(_ transactions: [Transaction], startDate: Date, endDate: Date) -> PeriodStats {
        guard !transactions.isEmpty else {
            return .empty(startDate: startDate, endDate: endDate)
        }

        let calendar = Calendar.current
        var totalIncome = 0.0
        var totalExpenses = 0.0
        var incomeCount = 0
        var expenseCount = 0
        var highestExpense: Transaction? = nil
        var lowestExpense: Transaction? = nil
        var highestIncome: Transaction? = nil
        var lowestIncome: Transaction? = nil
        var categoryTotals: [String: Double] = [:]
        var categoryCounts: [String: Int] = [:]
        var dailySpending: [Date: Double] = [:]
        var dailyIncomeMap: [Date: Double] = [:]

        for transaction in transactions {
            let day = calendar.startOfDay(for: transaction.date)
            categoryTotals[transaction.categoryId, default: 0] += transaction.amount
            categoryCounts[transaction.categoryId, default: 0] += 1

            if transaction.isIncome {
                totalIncome += transaction.amount
                incomeCount += 1
                dailyIncomeMap[day, default: 0] += transaction.amount
                if highestIncome == nil || transaction.amount > highestIncome!.amount { highestIncome = transaction }
                if lowestIncome == nil || transaction.amount < lowestIncome!.amount { lowestIncome = transaction }
            } else {
                totalExpenses += transaction.amount
                expenseCount += 1
                dailySpending[day, default: 0] += transaction.amount
                if highestExpense == nil || transaction.amount > highestExpense!.amount { highestExpense = transaction }
                if lowestExpense == nil || transaction.amount < lowestExpense!.amount { lowestExpense = transaction }
            }
        }

        let totalAmount = totalIncome + totalExpenses
        let netBalance = totalIncome - totalExpenses
        let savingsRate = totalIncome > 0 ? (netBalance / totalIncome) * 100 : 0.0
        let daysDifference = max(calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
        let averagePerDay = totalExpenses / Double(daysDifference)
        let averagePerTransaction = totalAmount / Double(transactions.count)

        var dailyNet: [Date: Double] = [:]
        for date in Set(dailySpending.keys).union(dailyIncomeMap.keys) {
            dailyNet[date] = (dailyIncomeMap[date] ?? 0) - (dailySpending[date] ?? 0)
        }

        return PeriodStats(
            totalAmount: totalAmount,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            netBalance: netBalance,
            savingsRate: savingsRate,
            transactionCount: transactions.count,
            incomeCount: incomeCount,
            expenseCount: expenseCount,
            averagePerDay: averagePerDay,
            averagePerTransaction: averagePerTransaction,
            highestExpense: highestExpense,
            lowestExpense: lowestExpense,
            highestIncome: highestIncome,
            lowestIncome: lowestIncome,
            categoryBreakdown: [],
            dailySpending: dailySpending,
            dailyIncome: dailyIncomeMap,
            dailyNet: dailyNet,
            startDate: startDate,
            endDate: endDate,
            categoryTotals: categoryTotals,
            categoryCounts: categoryCounts
        )
    }

    /// Create a copy with calculated category breakdown
    func withCategoryBreakdown(categories: [Category]) -> PeriodStats {
        var breakdown: [CategoryStats] = []
        for (categoryId, total) in categoryTotals {
            guard let category = categories.first(where: { $0.id == categoryId })
                    ?? categories.first(where: { $0.id == "other_expense" }) else { continue }
            let grandTotal = category.type == .expense ? totalExpenses : totalIncome
            breakdown.append(CategoryStats(
                categoryId: category.id,
                categoryName: category.name,
                totalAmount: total,
                count: categoryCounts[categoryId] ?? 0,
                percentage: grandTotal > 0 ? (total / grandTotal) * 100 : 0,
                colorHex: category.colorHex,
                iconName: category.iconName,
                type: category.type
            ))
        }
        breakdown.sort { $0.totalAmount > $1.totalAmount }

        return PeriodStats(
            totalAmount: totalAmount, totalIncome: totalIncome, totalExpenses: totalExpenses,
            netBalance: netBalance, savingsRate: savingsRate,
            transactionCount: transactionCount, incomeCount: incomeCount, expenseCount: expenseCount,
            averagePerDay: averagePerDay, averagePerTransaction: averagePerTransaction,
            highestExpense: highestExpense, lowestExpense: lowestExpense,
            highestIncome: highestIncome, lowestIncome: lowestIncome,
            categoryBreakdown: breakdown,
            dailySpending: dailySpending, dailyIncome: dailyIncome, dailyNet: dailyNet,
            startDate: startDate, endDate: endDate,
            categoryTotals: categoryTotals, categoryCounts: categoryCounts
        )
    }

    var incomeCategoryBreakdown: [CategoryStats] {
        categoryBreakdown.filter { $0.type == .income }
    }

    var expenseCategoryBreakdown: [CategoryStats] {
        categoryBreakdown.filter { $0.type == .expense }
    }
}
