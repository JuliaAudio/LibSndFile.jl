# convenience function to calculate the mean-squared error
function mse(arr1::AbstractArray, arr2::AbstractArray)
    @assert length(arr1) == length(arr2)
    N = length(arr1)
    err = 0.0
    for i in 1:N
        err += (arr2[i] - arr1[i])^2
    end
    err /= N
end
