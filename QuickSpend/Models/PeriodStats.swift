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

        let incomeItems = transactions.filter(\.isIncome)
        let expenseItems = transactions.filter(\.isExpense)

        let totalIncome = incomeItems.reduce(0.0) { $0 + $1.amount }
        let totalExpenses = expenseItems.reduce(0.0) { $0 + $1.amount }
        let totalAmount = totalIncome + totalExpenses
        let netBalance = totalIncome - totalExpenses
        let savingsRate = totalIncome > 0 ? (netBalance / totalIncome) * 100 : 0.0

        let calendar = Calendar.current
        let daysDifference = max(calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 1, 1)
        let averagePerDay = totalExpenses / Double(daysDifference)
        let averagePerTransaction = transactions.isEmpty ? 0 : totalAmount / Double(transactions.count)

        // Highest/lowest
        let sortedExpenses = expenseItems.sorted { $0.amount > $1.amount }
        let sortedIncome = incomeItems.sorted { $0.amount > $1.amount }

        // Category breakdown
        var categoryTotals: [String: Double] = [:]
        var categoryCounts: [String: Int] = [:]
        for transaction in transactions {
            categoryTotals[transaction.categoryId, default: 0] += transaction.amount
            categoryCounts[transaction.categoryId, default: 0] += 1
        }

        // Daily aggregations
        var dailySpending: [Date: Double] = [:]
        var dailyIncomeMap: [Date: Double] = [:]
        for item in expenseItems {
            let day = calendar.startOfDay(for: item.date)
            dailySpending[day, default: 0] += item.amount
        }
        for item in incomeItems {
            let day = calendar.startOfDay(for: item.date)
            dailyIncomeMap[day, default: 0] += item.amount
        }
        var dailyNet: [Date: Double] = [:]
        let allDates = Set(dailySpending.keys).union(dailyIncomeMap.keys)
        for date in allDates {
            dailyNet[date] = (dailyIncomeMap[date] ?? 0) - (dailySpending[date] ?? 0)
        }

        return PeriodStats(
            totalAmount: totalAmount,
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            netBalance: netBalance,
            savingsRate: savingsRate,
            transactionCount: transactions.count,
            incomeCount: incomeItems.count,
            expenseCount: expenseItems.count,
            averagePerDay: averagePerDay,
            averagePerTransaction: averagePerTransaction,
            highestExpense: sortedExpenses.first,
            lowestExpense: sortedExpenses.last,
            highestIncome: sortedIncome.first,
            lowestIncome: sortedIncome.last,
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
