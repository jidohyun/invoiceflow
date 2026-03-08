package com.invoiceflow.core.domain

import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.withContext

abstract class UseCase<in P, R>(
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    suspend operator fun invoke(params: P): Result<R> = withContext(dispatcher) {
        try {
            Result.Success(execute(params))
        } catch (e: Exception) {
            Result.Error(e.message ?: "Unknown error", e)
        }
    }

    protected abstract suspend fun execute(params: P): R
}

abstract class FlowUseCase<in P, R>(
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO,
) {
    operator fun invoke(params: P): Flow<Result<R>> = execute(params)
        .catch { emit(Result.Error(it.message ?: "Unknown error", it)) }
        .flowOn(dispatcher)

    protected abstract fun execute(params: P): Flow<Result<R>>
}
